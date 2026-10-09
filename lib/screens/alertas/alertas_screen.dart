import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../widgets/watermark_background.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';

class AlertasScreen extends StatefulWidget {
  final bool isVehicleContext;
  final String? userRole;
  final String? viewContext;

  const AlertasScreen({
    super.key,
    this.isVehicleContext = false,
    this.userRole,
    this.viewContext,
  });

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  UsuarioModel? _perfil;
  List<OcorrenciaModel> _ocorrencias = [];
  List<DispositivoModel> _dispositivos = [];
  List<FrotaModel> _frotas = [];
  
  FrotaModel? _selectedFrota;
  DispositivoModel? _selectedDevice;

  String _periodoSelecionado = 'Todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccessAndFetch();
    });
  }

  Future<void> _checkAccessAndFetch() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.currentUser;
      if (user == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      _perfil = await _supabase.getUsuarioPerfil(user.id);
      final role = _perfil?.role ?? '';

      // Regra de permissão: Operador não acessa Alertas — Frota
      if (!widget.isVehicleContext && role == 'operador') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Acesso negado para seu perfil. Redirecionando para Veículo.', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushReplacementNamed(context, '/alertas-veiculo');
        }
        return;
      }

      // Checar argumento de rota para veículo inicial
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      DispositivoModel? argDevice;
      if (routeArg is DispositivoModel) {
        argDevice = routeArg;
      }

      // Buscar frotas e dispositivos de acordo com o papel
      List<FrotaModel> frotas = [];
      List<DispositivoModel> devs = [];

      if (role == 'admin') {
        frotas = await _supabase.getFrotas();
        devs = await _supabase.getDispositivos();
      } else if (role == 'gerente') {
        frotas = await _supabase.getFrotasByGerente(user.id);
        for (var f in frotas) {
          final fDevs = await _supabase.getDispositivosByFrota(f.id);
          devs.addAll(fDevs);
        }
      } else {
        // Operador
        devs = await _supabase.getDispositivosByOperador(user.id);
      }

      _frotas = frotas;
      _dispositivos = devs;

      if (widget.isVehicleContext) {
        if (argDevice != null && devs.any((d) => d.id == argDevice.id)) {
          _selectedDevice = devs.firstWhere((d) => d.id == argDevice.id);
        } else if (devs.isNotEmpty) {
          _selectedDevice = devs.first;
        }
      } else {
        if (frotas.isNotEmpty) {
          _selectedFrota = frotas.first;
        }
      }

      await _loadOcorrencias();
    } catch (e) {
      debugPrint('Erro ao buscar alertas: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOcorrencias() async {
    DateTime agora = DateTime.now();
    DateTime inicio = agora.subtract(const Duration(days: 365)); // Todos
    
    if (_periodoSelecionado == 'Hoje') {
      inicio = DateTime(agora.year, agora.month, agora.day);
    } else if (_periodoSelecionado == 'Semana') {
      inicio = agora.subtract(Duration(days: agora.weekday - 1));
      inicio = DateTime(inicio.year, inicio.month, inicio.day);
    }
    
    List<String> targetDeviceIds = [];

    if (widget.isVehicleContext) {
      if (_selectedDevice != null) {
        targetDeviceIds = [_selectedDevice!.id];
      } else {
        targetDeviceIds = _dispositivos.map((d) => d.id).toList();
      }
    } else {
      if (_selectedFrota != null) {
        targetDeviceIds = _dispositivos.where((d) => d.idFrota == _selectedFrota!.id).map((d) => d.id).toList();
      } else {
        targetDeviceIds = _dispositivos.map((d) => d.id).toList();
      }
    }

    if (targetDeviceIds.isNotEmpty) {
      _ocorrencias = await _supabase.getOcorrenciasFiltro(targetDeviceIds, inicio, agora);
      _ocorrencias.sort((a, b) => (b.criadoEm ?? agora).compareTo(a.criadoEm ?? agora));
    } else {
      _ocorrencias = [];
    }
    
    if (mounted) setState(() {});
  }

  void _onSwitchFrota(FrotaModel f) async {
    setState(() {
      _selectedFrota = f;
      _isLoading = true;
    });
    await _loadOcorrencias();
    if (mounted) setState(() => _isLoading = false);
  }

  void _onSwitchDevice(DispositivoModel d) async {
    setState(() {
      _selectedDevice = d;
      _isLoading = true;
    });
    await _loadOcorrencias();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.isVehicleContext ? 'Alertas — Veículo' : 'Alertas — Frota';

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 0,
        isVehicleContext: widget.isVehicleContext,
        currentDevice: _selectedDevice,
      ),
      body: WatermarkBackground(
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFC23147)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, title),
                    const SizedBox(height: 16),
                    _buildContextFilter(),
                    const SizedBox(height: 16),
                    _buildFiltroDropdown(),
                    const SizedBox(height: 16),
                    _buildStatusCard(),
                    const SizedBox(height: 24),
                    const Text(
                      'ALERTAS RECENTES',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_ocorrencias.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'Nenhum alerta encontrado para o filtro selecionado.',
                            style: TextStyle(fontSize: 16, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ..._ocorrencias.map((o) => _buildAlertCard(o)),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    final role = _perfil?.role ?? '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back,
                color: Color(0xFFC23147),
                size: 28,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFC23147),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC23147),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                role.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        GestureDetector(
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
      ],
    );
  }

  Widget _buildContextFilter() {
    if (widget.isVehicleContext) {
      if (_dispositivos.length <= 1) {
        final d = _selectedDevice;
        final name = d != null ? (d.placaVeiculo ?? d.nomeDispositivo ?? 'Veículo') : 'Nenhum veículo';
        return _buildBadge('Veículo: $name');
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<DispositivoModel>(
            value: _selectedDevice,
            isExpanded: true,
            hint: const Text('Selecione o Veículo'),
            items: _dispositivos.map((d) {
              return DropdownMenuItem(
                value: d,
                child: Text(
                  '${d.placaVeiculo ?? d.nomeDispositivo ?? "Veículo"} (${d.modeloVeiculo ?? "Dispositivo"})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _onSwitchDevice(val);
            },
          ),
        ),
      );
    } else {
      // Frota Context
      if (_frotas.length <= 1) {
        final f = _selectedFrota;
        final name = f != null ? f.nome : 'Todas as Frotas';
        return _buildBadge('Frota: $name (${_dispositivos.length} veículos)');
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<FrotaModel>(
            value: _selectedFrota,
            isExpanded: true,
            hint: const Text('Selecione a Frota'),
            items: _frotas.map((f) {
              final count = _dispositivos.where((d) => d.idFrota == f.id).length;
              return DropdownMenuItem(
                value: f,
                child: Text(
                  '${f.nome} ($count veículos)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _onSwitchFrota(val);
            },
          ),
        ),
      );
    }
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.black87),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFiltroDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButton<String>(
        value: _periodoSelecionado,
        isExpanded: true,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'Todos', child: Text('Todos os períodos')),
          DropdownMenuItem(value: 'Hoje', child: Text('Hoje')),
          DropdownMenuItem(value: 'Semana', child: Text('Esta Semana')),
        ],
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _periodoSelecionado = val;
              _isLoading = true;
            });
            _loadOcorrencias().then((_) => setState(() => _isLoading = false));
          }
        },
      ),
    );
  }

  Widget _buildStatusCard() {
    int ativos = _ocorrencias.where((o) => o.status != 'Resolvido').length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC23147),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status Geral', style: TextStyle(color: Colors.white70, fontSize: 14)),
                SizedBox(height: 4),
                Text('Atenção Necessária', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(ativos.toString(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Ativos', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(OcorrenciaModel o) {
    bool isCritical = o.tipo != null && o.tipo!.toLowerCase().contains('crítico');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCritical ? const Color(0xFFFEEBEE) : const Color(0xFFFFF8E1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCritical ? Icons.warning_rounded : Icons.info_outline,
                  color: isCritical ? const Color(0xFFC23147) : Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.tipo ?? 'Alerta Registrado',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Disp: ${o.idDispositivo?.substring(0, 8) ?? 'N/D'} | Valor: ${o.valorRegistrado ?? '-'}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.black54, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    o.criadoEm != null ? '${o.criadoEm!.day}/${o.criadoEm!.month} ${o.criadoEm!.hour}:${o.criadoEm!.minute.toString().padLeft(2, '0')}' : '',
                    style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
