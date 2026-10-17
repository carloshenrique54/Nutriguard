import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';
import '../../services/admin_context_service.dart';
import '../../widgets/responsive_layout.dart';
import '../../services/trip_service.dart';

class DashboardFrotaScreen extends StatefulWidget {
  final String? initialFrotaId;
  final SupabaseService? supabaseService;

  const DashboardFrotaScreen({
    super.key,
    this.initialFrotaId,
    this.supabaseService,
  });

  @override
  State<DashboardFrotaScreen> createState() => _DashboardFrotaScreenState();
}

class _DashboardFrotaScreenState extends State<DashboardFrotaScreen> {
  late final SupabaseService _supabase;
  bool _isLoading = true;
  String _userName = '';
  String _userRole = '';
  
  List<FrotaModel> _frotas = [];
  FrotaModel? _selectedFrota;
  List<DispositivoModel> _dispositivos = [];
  Map<String, int> _frotaDeviceCounts = {};
  List<OcorrenciaModel> _alerts = [];
  int _totalSystemDevices = 0;
  Set<String> _devicesInTrip = {};

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseService ?? SupabaseService();
    TripService().tripStateNotifier.addListener(_onTripStateChanged);
    _checkAccess();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    TripService().tripStateNotifier.removeListener(_onTripStateChanged);
    super.dispose();
  }

  void _onTripStateChanged() {
    if (mounted) {
      _updateActiveTrips(_dispositivos);
    }
  }

  Future<void> _updateActiveTrips(List<DispositivoModel> devices) async {
    final tripService = TripService();
    final Set<String> inTrip = {};
    for (final d in devices) {
      final active = await tripService.isDeviceInTrip(d.id, operatorId: d.idOperador);
      if (active) {
        inTrip.add(d.id);
      }
    }
    if (mounted) {
      setState(() {
        _devicesInTrip = inTrip;
      });
    }
  }

  Future<void> _checkAccess() async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final perfil = await _supabase.getUsuarioPerfil(currentUserId);
    final role = perfil?.role ?? '';
    
    // Operador não tem acesso ao Dashboard de Frota
    if (role != 'admin' && role != 'gerente') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acesso negado para seu perfil. Redirecionando para Veículo.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushReplacementNamed(context, '/dashboard-veiculo');
      }
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = _supabase.currentUser?.id;
      if (currentUserId == null) return;
      
      final perfil = await _supabase.getUsuarioPerfil(currentUserId);
      if (perfil != null) {
        _userName = perfil.nome ?? 'Usuário';
        _userRole = perfil.role;
      }

      // Buscar frotas de acordo com a regra de permissão:
      // ADM: todas as frotas
      // Gerente: apenas frotas em que é id_gerente
      List<FrotaModel> frotas = [];
      if (_userRole == 'admin') {
        frotas = await _supabase.getFrotas();
      } else {
        frotas = await _supabase.getFrotasByGerente(currentUserId);
      }

      // Buscar todos os dispositivos do sistema para checagem de estado vazio (ADM)
      final allSystemDevices = await _supabase.getDispositivos();
      _totalSystemDevices = allSystemDevices.length;

      // Definir frota selecionada (se passada por argumento ou contexto do ADM)
      FrotaModel? selected;
      if (!mounted) return;
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      if (routeArg is FrotaModel) {
        selected = frotas.where((f) => f.id == routeArg.id).firstOrNull ?? routeArg;
      } else if (routeArg is String) {
        selected = frotas.where((f) => f.id == routeArg).firstOrNull;
      } else if (widget.initialFrotaId != null) {
        selected = frotas.where((f) => f.id == widget.initialFrotaId).firstOrNull;
      } else if (_userRole == 'admin' && AdminContextService().selectedFrota != null) {
        final id = AdminContextService().selectedFrota!.id;
        selected = frotas.where((f) => f.id == id).firstOrNull ?? AdminContextService().selectedFrota;
      } else if (_userRole == 'admin' && frotas.length == 1) {
        selected = frotas.first;
      } else if (_userRole != 'admin' && frotas.isNotEmpty) {
        selected = frotas.first;
      }

      if (_userRole == 'admin' && selected != null) {
        AdminContextService().setFrota(selected);
        AdminContextService().clearVehicle();
      }

      // Dispositivos da frota selecionada ou de todas as frotas do gerente/admin
      List<DispositivoModel> activeDevices = [];
      if (selected != null) {
        activeDevices = await _supabase.getDispositivosByFrota(selected.id);
      } else if (frotas.isNotEmpty) {
        for (var f in frotas) {
          final devs = await _supabase.getDispositivosByFrota(f.id);
          activeDevices.addAll(devs);
        }
      }

      // Contagem de dispositivos por frota
      Map<String, int> counts = {};
      for (var f in frotas) {
        counts[f.id] = allSystemDevices.where((d) => d.idFrota == f.id).length;
      }

      // Ocorrências recentes dos dispositivos da frota
      List<String> devIds = activeDevices.map((d) => d.id).toList();
      DateTime agora = DateTime.now();
      DateTime inicio = agora.subtract(const Duration(days: 30));
      List<OcorrenciaModel> ocorrencias = await _supabase.getOcorrenciasFiltro(devIds, inicio, agora);
      ocorrencias.sort((a, b) => (b.criadoEm ?? agora).compareTo(a.criadoEm ?? agora));

      if (mounted) {
        setState(() {
          _frotas = frotas;
          _selectedFrota = selected;
          _dispositivos = activeDevices;
          _frotaDeviceCounts = counts;
          _alerts = ocorrencias.take(5).toList();
          _isLoading = false;
        });
        _updateActiveTrips(activeDevices);
      }
    } catch (e) {
      debugPrint('Erro ao carregar Dashboard Frota: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSelectFrota(FrotaModel f) async {
    if (_userRole == 'admin') {
      AdminContextService().setFrota(f);
      AdminContextService().clearVehicle();
    }
    setState(() {
      _selectedFrota = f;
      _isLoading = true;
    });
    try {
      final devs = await _supabase.getDispositivosByFrota(f.id);
      List<String> devIds = devs.map((d) => d.id).toList();
      DateTime agora = DateTime.now();
      DateTime inicio = agora.subtract(const Duration(days: 30));
      final ocorrencias = await _supabase.getOcorrenciasFiltro(devIds, inicio, agora);
      ocorrencias.sort((a, b) => (b.criadoEm ?? agora).compareTo(a.criadoEm ?? agora));

      if (mounted) {
        setState(() {
          _dispositivos = devs;
          _alerts = ocorrencias.take(5).toList();
          _isLoading = false;
        });
        _updateActiveTrips(devs);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = _frotas.isEmpty || _dispositivos.isEmpty;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 2,
        isVehicleContext: false,
        isDisabled: isEmpty,
        hasFleetsOverride: _frotas.isNotEmpty,
        hasDevicesOverride: _dispositivos.isNotEmpty,
        userRoleOverride: _userRole.isNotEmpty ? _userRole : null,
      ),
      body: WatermarkBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFC23147)))
              : _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // 1. Caso: Gerente sem frota associada
    if (_frotas.isEmpty && _userRole == 'gerente') {
      return ResponsiveContentWrapper(
        maxWidth: 700,
        child: _buildEmptyFrotaGerente(),
      );
    }

    // 2. Caso: Nenhuma frota cadastrada (ADM)
    if (_frotas.isEmpty && _userRole == 'admin') {
      return ResponsiveContentWrapper(
        maxWidth: 700,
        child: _buildEmptyFrotasAdmin(),
      );
    }

    // 3. Caso: Nenhuma frota selecionada (ADM)
    if (_selectedFrota == null && _userRole == 'admin') {
      return ResponsiveContentWrapper(
        maxWidth: 700,
        child: _buildNoFrotaSelectedAdmin(),
      );
    }

    // 4. Caso: A frota selecionada não tem dispositivos cadastrados
    if (_selectedFrota != null && _dispositivos.isEmpty) {
      return ResponsiveContentWrapper(
        maxWidth: 700,
        child: _buildEmptyFrotaDevices(context),
      );
    }

    return ResponsiveContentWrapper(
      maxWidth: 1200,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= ResponsiveBreakpoints.desktop;
          if (isDesktop) {
            return _buildDesktopLayout(context);
          } else {
            return _buildMobileLayout(context);
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          _buildFrotaSelector(),
          const SizedBox(height: 16),
          _buildManagementCard(),
          const SizedBox(height: 14),
          _buildSplitCard(),
          const SizedBox(height: 14),
          _buildTwoColumnCards(),
          const SizedBox(height: 18),
          _buildOutrasFrotasSection(),
          const SizedBox(height: 18),
          _buildRecentEvents(),
          const SizedBox(height: 18),
          _buildVeiculosList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 14),
          _buildFrotaSelector(),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coluna Esquerda: Gestão, Limites térmicos, Indicadores e Outras frotas
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildManagementCard(),
                    const SizedBox(height: 16),
                    _buildSplitCard(),
                    const SizedBox(height: 16),
                    _buildTwoColumnCards(),
                    const SizedBox(height: 18),
                    _buildOutrasFrotasSection(),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Coluna Direita: Alertas recentes e Lista/Tabela de veículos
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRecentEvents(),
                    const SizedBox(height: 18),
                    _buildVeiculosList(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyFrotaDevices(BuildContext context) {
    final bool isAdmin = _userRole.toLowerCase() == 'admin' || _userRole.toLowerCase() == 'adm';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (_frotas.length > 1) ...[
            const SizedBox(height: 16),
            _buildFrotaSelector(),
          ],
          const SizedBox(height: 48),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.devices_other_outlined, size: 72, color: Color(0xFFC23147)),
                const SizedBox(height: 16),
                const Text(
                  'Nenhum dispositivo cadastrado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isAdmin
                      ? 'Esta frota ainda não possui dispositivos vinculados.'
                      : 'Esta frota ainda não possui dispositivos vinculados.',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (isAdmin)
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/cadastrar-dispositivo',
                      arguments: _selectedFrota?.id,
                    ).then((_) => _fetchData()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC23147),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Cadastrar dispositivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _fetchData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC23147),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text('Atualizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyFrotasAdmin() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 72, color: Color(0xFFC23147)),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhuma frota cadastrada',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _totalSystemDevices > 0
                          ? 'Existem $_totalSystemDevices dispositivos cadastrados prontos para uso. Crie uma frota para associá-los!'
                          : 'Nenhuma frota cadastrada no sistema. Comece criando uma nova frota!',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/criar-frota').then((_) => _fetchData()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC23147),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Criar frota', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildNoFrotaSelectedAdmin() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fire_truck_outlined, size: 72, color: Color(0xFFC23147)),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhuma frota selecionada',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Para visualizar métricas, relatórios e veículos no Dashboard, selecione uma frota primeiro.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/listar-frotas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC23147),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.format_list_bulleted, color: Colors.white),
                      label: const Text('Selecionar frota', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyFrotaGerente() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 72, color: Color(0xFFC23147)),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhuma frota atribuída',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Você não possui nenhuma frota sob sua responsabilidade. A configuração e associação deve ser realizada pelo Administrador.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _fetchData(),
                          icon: const Icon(Icons.refresh, color: Color(0xFFC23147)),
                          label: const Text(
                            'Atualizar',
                            style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFC23147)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _supabase.signOut();
                            if (mounted) {
                              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                            }
                          },
                          icon: const Icon(Icons.logout, color: Colors.white),
                          label: const Text(
                            'Sair da conta',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC23147),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bool isGerenteEmpty = _userRole == 'gerente' && _frotas.isEmpty;
    final bool isFrotaEmpty = _dispositivos.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              (isGerenteEmpty || isFrotaEmpty) ? 'Dashboard — Frota' : 'Dashboard',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC23147),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC23147),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _userRole == 'admin' ? 'ADM' : _userRole.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => CustomEndDrawer.showMenu(
                  context,
                  userRoleOverride: _userRole.isNotEmpty ? _userRole : null,
                  hasFleetsOverride: _frotas.isNotEmpty,
                  hasDevicesOverride: _dispositivos.isNotEmpty,
                ),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Image.asset(
                    'assets/images/logo.png',
                    color: const Color(0xFFC23147),
                    width: 38,
                    height: 38,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (isGerenteEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                'Olá, $_userName',
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFrotaSelector() {
    final frotaNome = _selectedFrota?.nome ?? "Frota Sul";
    final devCount = _dispositivos.length;

    if (_frotas.length <= 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_outlined, color: Color(0xFF8DB600), size: 16),
            const SizedBox(width: 6),
            const Text('Vendo: ', style: TextStyle(color: Colors.black54, fontSize: 12)),
            Text(
              '$frotaNome ($devCount veículos)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<FrotaModel>(
      onSelected: _onSelectFrota,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => _frotas.map((f) {
        final count = _frotaDeviceCounts[f.id] ?? 0;
        final isSelected = f.id == _selectedFrota?.id;
        return PopupMenuItem<FrotaModel>(
          value: f,
          child: Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                color: isSelected ? const Color(0xFFC23147) : Colors.black54,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                f.nome ?? 'Sem Nome',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFFC23147) : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Text('($count veículos)', style: const TextStyle(color: Colors.black45, fontSize: 11)),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_outlined, color: Color(0xFF8DB600), size: 16),
            const SizedBox(width: 6),
            const Text('Vendo: ', style: TextStyle(color: Colors.black54, fontSize: 12)),
            Text(
              '$frotaNome ($devCount veículos)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementCard() {
    final devCount = _dispositivos.length;
    final int critCount = _alerts.where((a) => a.tipo != null && a.tipo!.toLowerCase().contains('crítico')).map((a) => a.idDispositivo).toSet().length;
    final int warnCount = _alerts.where((a) => a.tipo == null || !a.tipo!.toLowerCase().contains('crítico')).map((a) => a.idDispositivo).toSet().length;
    final int normCount = (devCount - critCount - warnCount) > 0 ? (devCount - critCount - warnCount) : (devCount > 0 ? devCount : 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFB5D95C),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gerenciamento\nde frota',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedCounterText(
                      value: devCount,
                      suffix: '',
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Veiculos',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildPillDot(const Color(0xFF8DB600), '$normCount Normais'),
                    _buildPillDot(const Color(0xFFFFA000), '$warnCount Atenção'),
                    _buildPillDot(const Color(0xFFC23147), '$critCount Crítico'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.local_shipping_outlined,
                color: Color(0xFFC23147),
                size: 46,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillDot(Color dotColor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC23147),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.thermostat, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Temperatura média',
                        style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        '8°C',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 38,
            width: 1,
            color: Colors.black12,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC23147),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.access_time, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Última atualização',
                        style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        '1 minuto(s) atrás',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoColumnCards() {
    final devCount = _dispositivos.length;
    final emViagemCount = _devicesInTrip.length;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC23147),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.water_drop, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Umidade média', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
                          Text('32%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFC23147))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7EBB0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Dentro do limite',
                        style: TextStyle(color: Color(0xFF2E7D32), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    RichText(
                      text: const TextSpan(
                        text: 'Limite definido: ',
                        style: TextStyle(fontSize: 9, color: Colors.black54),
                        children: [
                          TextSpan(
                            text: '40%',
                            style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC23147),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.wifi, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Veículos em viagem', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
                          Text(
                            devCount > 0 ? '$emViagemCount/$devCount' : '0/0',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: emViagemCount > 0 ? const Color(0xFFD7EBB0) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        emViagemCount > 0 ? '$emViagemCount em trânsito' : 'Nenhum em trânsito',
                        style: TextStyle(
                          color: emViagemCount > 0 ? const Color(0xFF2E7D32) : Colors.black54,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      devCount > 0 ? '${devCount - emViagemCount} parado(s)' : 'Sem veículos',
                      style: const TextStyle(fontSize: 9, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutrasFrotasSection() {
    final otherFrotas = _frotas.where((f) => f.id != _selectedFrota?.id).toList();
    final displayFrotas = otherFrotas.isNotEmpty ? otherFrotas : _frotas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Outras frotas',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/listar-frotas'),
              child: const Text(
                'Ver todas >',
                style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayFrotas.length,
            separatorBuilder: (_, index) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final f = displayFrotas[i];
              final count = _frotaDeviceCounts[f.id] ?? 0;
              final isSel = f.id == _selectedFrota?.id;

              return InkWell(
                onTap: () => _onSelectFrota(f),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 136,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? const Color(0xFFC23147) : Colors.black12,
                      width: isSel ? 1.5 : 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        f.nome ?? 'Frota',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count Veículos',
                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildDotCounter(const Color(0xFF8DB600), count > 2 ? count - 1 : count),
                          const SizedBox(width: 6),
                          _buildDotCounter(const Color(0xFFFFA000), count > 2 ? 1 : 0),
                          const SizedBox(width: 6),
                          _buildDotCounter(const Color(0xFFC23147), 0),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDotCounter(Color color, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text('$value', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54)),
      ],
    );
  }

  Widget _buildRecentEvents() {
    final devFirst = _dispositivos.firstOrNull;
    final veiculoNome = devFirst?.modeloVeiculo ?? devFirst?.placaVeiculo ?? 'Volvo FH 540';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Eventos recentes',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/alertas-frota'),
              child: const Text('Ver todos >', style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              _buildEventItem(
                icon: Icons.thermostat,
                iconBg: const Color(0xFFD7EBB0),
                iconColor: const Color(0xFF2E7D32),
                title: 'Condições normais',
                veiculoTag: 'Veículo: $veiculoNome',
                metricsText: 'Temperatura: 5,4°C  |  Umidade: 32%',
                time: '09:41',
              ),
              const Divider(height: 18),
              _buildEventItem(
                icon: Icons.graphic_eq,
                iconBg: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF689F38),
                title: 'Impacto leve detectado',
                veiculoTag: 'Veículo: $veiculoNome',
                metricsText: 'Intensidade: 1,8 g',
                time: '09:41',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String veiculoTag,
    required String metricsText,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                  const SizedBox(width: 6),
                  Text(veiculoTag, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                metricsText,
                style: const TextStyle(fontSize: 11, color: Color(0xFFC23147), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 14, color: Color(0xFFC23147)),
            const SizedBox(width: 3),
            Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFFC23147), fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildVeiculosList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Veículos da Frota',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            GestureDetector(
              onTap: () {
                if (_selectedFrota != null && _userRole == 'admin') {
                  AdminContextService().setFrota(_selectedFrota);
                }
                Navigator.pushNamed(context, '/listar-dispositivos', arguments: _selectedFrota);
              },
              child: const Text(
                'Ver detalhes >',
                style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_dispositivos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const Text('Nenhum dispositivo cadastrado', style: TextStyle(color: Colors.black54), textAlign: TextAlign.center),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: _dispositivos.map((d) {
                final isLast = d == _dispositivos.last;
                final isInTrip = _devicesInTrip.contains(d.id);
                return Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isInTrip ? const Color(0xFFD7EBB0) : const Color(0xFFC8E569),
                          child: Icon(Icons.directions_car, color: isInTrip ? const Color(0xFF2E7D32) : Colors.black87),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                d.placaVeiculo ?? d.nomeDispositivo ?? 'Veículo',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isInTrip ? const Color(0xFFE8F5E9) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isInTrip ? const Color(0xFF81C784) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                isInTrip ? 'Em viagem' : 'Parado',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isInTrip ? const Color(0xFF2E7D32) : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Modelo: ${d.modeloVeiculo ?? d.modeloDispositivo ?? "N/D"}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.black45),
                        onTap: () {
                          if (_userRole == 'admin') {
                            AdminContextService().setDevice(d, frota: _selectedFrota);
                          }
                          Navigator.pushNamed(context, '/dashboard-veiculo', arguments: d);
                        },
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
