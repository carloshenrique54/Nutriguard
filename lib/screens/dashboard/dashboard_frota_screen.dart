import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';

class DashboardFrotaScreen extends StatefulWidget {
  final String? initialFrotaId;

  const DashboardFrotaScreen({
    super.key,
    this.initialFrotaId,
  });

  @override
  State<DashboardFrotaScreen> createState() => _DashboardFrotaScreenState();
}

class _DashboardFrotaScreenState extends State<DashboardFrotaScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  String _userName = '';
  String _userRole = '';
  
  List<FrotaModel> _frotas = [];
  FrotaModel? _selectedFrota;
  List<DispositivoModel> _dispositivos = [];
  Map<String, int> _frotaDeviceCounts = {};
  List<OcorrenciaModel> _alerts = [];
  int _totalSystemDevices = 0;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
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

      // Definir frota selecionada (se passada por argumento ou a primeira da lista)
      FrotaModel? selected;
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      final argId = (routeArg is String ? routeArg : null) ?? widget.initialFrotaId;
      if (argId != null) {
        selected = frotas.where((f) => f.id == argId).firstOrNull;
      }
      selected ??= frotas.isNotEmpty ? frotas.first : null;

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
      }
    } catch (e) {
      debugPrint('Erro ao carregar Dashboard Frota: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSelectFrota(FrotaModel f) async {
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
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 2, isVehicleContext: false),
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
    // 1. Caso: Não há dispositivos cadastrados no sistema
    if (_totalSystemDevices == 0) {
      return _buildEmptySystemDevices();
    }

    // 2. Caso: Há dispositivos, mas nenhuma frota cadastrada
    if (_frotas.isEmpty && _userRole == 'admin') {
      return _buildEmptyFrotasAdmin();
    }

    // 3. Caso: Gerente sem frota associada
    if (_frotas.isEmpty && _userRole == 'gerente') {
      return _buildEmptyFrotaGerente();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildFrotaSelector(),
          const SizedBox(height: 16),
          _buildManagementCard(),
          const SizedBox(height: 16),
          _buildMetricsGrid(),
          const SizedBox(height: 16),
          _buildVeiculosList(),
          const SizedBox(height: 16),
          _buildRecentEvents(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptySystemDevices() {
    final bool isAdmin = _userRole == 'admin';
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
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
                  ? 'É necessário cadastrar um dispositivo antes de criar uma frota no sistema.'
                  : 'Nenhum dispositivo disponível no momento. A configuração depende do Administrador.',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isAdmin)
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/cadastrar-dispositivo').then((_) => _fetchData()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC23147),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Cadastrar dispositivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFrotasAdmin() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
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
              'Existem $_totalSystemDevices dispositivos cadastrados prontos para uso. Crie a primeira frota para associá-los!',
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
    );
  }

  Widget _buildEmptyFrotaGerente() {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 72, color: Color(0xFFC23147)),
            SizedBox(height: 16),
            Text(
              'Nenhuma frota atribuída',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Você não possui nenhuma frota sob sua responsabilidade. A configuração e associação deve ser realizada pelo Administrador.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Dashboard — Frota',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC23147),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC23147),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _userRole.toUpperCase(),
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
                onTap: () => CustomEndDrawer.showMenu(context),
                child: SizedBox(
                  width: 48,
                  height: 48,
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
    );
  }

  Widget _buildFrotaSelector() {
    if (_frotas.length <= 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_shipping, color: Color(0xFFC23147), size: 20),
            const SizedBox(width: 10),
            Text(
              'Frota: ${_selectedFrota?.nome ?? "Principal"}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FrotaModel>(
          value: _selectedFrota,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC23147)),
          items: _frotas.map((f) {
            final count = _frotaDeviceCounts[f.id] ?? 0;
            return DropdownMenuItem<FrotaModel>(
              value: f,
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: Color(0xFFC23147), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    f.nome ?? 'Sem Nome',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(width: 8),
                  Text('($count veículos)', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) _onSelectFrota(val);
          },
        ),
      ),
    );
  }

  Widget _buildManagementCard() {
    final devCount = _dispositivos.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Veículos monitorados',
                  style: TextStyle(color: Colors.black87, fontSize: 13),
                ),
                const SizedBox(height: 4),
                AnimatedCounterText(
                  value: devCount,
                  suffix: devCount == 1 ? ' Veículo' : ' Veículos',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusIndicator(Colors.green, '$devCount Ativos'),
                const SizedBox(height: 4),
                _buildStatusIndicator(Colors.orange, '${_alerts.length} Alertas'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Frotas acessíveis',
            value: _frotas.length.toString(),
            subtitle: _userRole == 'admin' ? 'Todas as frotas' : 'Sua frota',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Alertas recentes',
            value: _alerts.length.toString(),
            subtitle: 'Últimos 30 dias',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({required String title, required String value, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 15,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFC23147))),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black45)),
        ],
      ),
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
              onTap: () => Navigator.pushNamed(context, '/dashboard-veiculo'),
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
            child: const Text('Nenhum veículo vinculado a esta frota.', style: TextStyle(color: Colors.black54), textAlign: TextAlign.center),
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
                return Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFC8E569),
                        child: Icon(Icons.directions_car, color: Colors.black87),
                      ),
                      title: Text(
                        d.placaVeiculo ?? d.nomeDispositivo ?? 'Veículo',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Modelo: ${d.modeloVeiculo ?? d.modeloDispositivo ?? "N/D"}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.location_on_outlined, color: Color(0xFFC23147)),
                            onPressed: () {
                              Navigator.pushNamed(context, '/gps', arguments: d);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: Colors.black45),
                            onPressed: () {
                              Navigator.pushNamed(context, '/dashboard-veiculo', arguments: d);
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, '/dashboard-veiculo', arguments: d);
                      },
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

  Widget _buildRecentEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ocorrências recentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/alertas-frota'),
              child: const Text('Ver todas', style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
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
          child: _alerts.isEmpty
              ? const Center(child: Text("Nenhuma ocorrência recente", style: TextStyle(color: Colors.black54)))
              : Column(
                  children: _alerts.map((alerta) {
                    final time = alerta.criadoEm != null
                        ? '${alerta.criadoEm!.day}/${alerta.criadoEm!.month} ${alerta.criadoEm!.hour}:${alerta.criadoEm!.minute.toString().padLeft(2, '0')}'
                        : '';
                    return Column(
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFFFF2E0),
                              radius: 18,
                              child: Icon(Icons.warning_amber_rounded, color: Color(0xFFC23147), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alerta.tipo ?? 'Alerta',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text('Valor: ${alerta.valorRegistrado ?? "-"}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                ],
                              ),
                            ),
                            Text(time, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                        if (alerta != _alerts.last) const Divider(height: 16),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
