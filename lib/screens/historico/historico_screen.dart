import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';

class HistoricoScreen extends StatefulWidget {
  final bool isVehicleContext;
  final String? userRole;

  const HistoricoScreen({
    super.key,
    this.isVehicleContext = false,
    this.userRole,
  });

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  List<OcorrenciaModel> _alerts = [];
  String _userRole = '';
  
  List<DispositivoModel> _dispositivos = [];
  List<FrotaModel> _frotas = [];
  FrotaModel? _selectedFrota;
  DispositivoModel? _selectedDevice;

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
      final currentUserId = _supabase.currentUser?.id;
      if (currentUserId == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final perfil = await _supabase.getUsuarioPerfil(currentUserId);
      _userRole = perfil?.role ?? '';

      // Regra de permissão: Operador não acessa Histórico de Frota
      if (!widget.isVehicleContext && _userRole == 'operador') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Acesso negado para seu perfil. Redirecionando para Veículo.', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushReplacementNamed(context, '/historico-veiculo');
        }
        return;
      }

      // Argumento de rota
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      DispositivoModel? argDevice;
      if (routeArg is DispositivoModel) {
        argDevice = routeArg;
      }

      List<FrotaModel> frotas = [];
      List<DispositivoModel> devs = [];

      if (_userRole == 'admin') {
        frotas = await _supabase.getFrotas();
        devs = await _supabase.getDispositivos();
      } else if (_userRole == 'gerente') {
        frotas = await _supabase.getFrotasByGerente(currentUserId);
        for (var f in frotas) {
          final fDevs = await _supabase.getDispositivosByFrota(f.id);
          devs.addAll(fDevs);
        }
      } else {
        // Operador
        devs = await _supabase.getDispositivosByOperador(currentUserId);
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

      await _fetchHistory();
    } catch (e) {
      debugPrint('Erro ao carregar histórico: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHistory() async {
    List<String> targetIds = [];
    if (widget.isVehicleContext) {
      if (_selectedDevice != null) {
        targetIds = [_selectedDevice!.id];
      } else {
        targetIds = _dispositivos.map((d) => d.id).toList();
      }
    } else {
      if (_selectedFrota != null) {
        targetIds = _dispositivos.where((d) => d.idFrota == _selectedFrota!.id).map((d) => d.id).toList();
      } else {
        targetIds = _dispositivos.map((d) => d.id).toList();
      }
    }

    if (targetIds.isEmpty) {
      if (mounted) setState(() => _alerts = []);
      return;
    }

    DateTime agora = DateTime.now();
    DateTime inicio = agora.subtract(const Duration(days: 30));

    final ocorrencias = await _supabase.getOcorrenciasFiltro(targetIds, inicio, agora);
    ocorrencias.sort((a, b) => (b.criadoEm ?? agora).compareTo(a.criadoEm ?? agora));

    if (mounted) {
      setState(() {
        _alerts = ocorrencias;
      });
    }
  }

  void _onSwitchFrota(FrotaModel f) async {
    setState(() {
      _selectedFrota = f;
      _isLoading = true;
    });
    await _fetchHistory();
    if (mounted) setState(() => _isLoading = false);
  }

  void _onSwitchDevice(DispositivoModel d) async {
    setState(() {
      _selectedDevice = d;
      _isLoading = true;
    });
    await _fetchHistory();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.isVehicleContext ? 'Histórico — Veículo' : 'Histórico — Frota';

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 3,
        isVehicleContext: widget.isVehicleContext,
        currentDevice: _selectedDevice,
      ),
      body: WatermarkBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, title),
                const SizedBox(height: 12),
                _buildContextFilter(),
                const SizedBox(height: 16),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFFC23147),
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      await _fetchHistory();
                    },
                    child: _isLoading
                        ? ListView.builder(
                            itemCount: 4,
                            itemBuilder: (context, index) => const Padding(
                              padding: EdgeInsets.only(bottom: 16.0),
                              child: ShimmerEffect(
                                width: double.infinity,
                                height: 90,
                                borderRadius: 12,
                              ),
                            ),
                          )
                        : _alerts.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.history_toggle_off_outlined, size: 56, color: Color(0xFFC23147)),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Nenhum evento registrado no histórico recente.',
                                        style: TextStyle(fontSize: 15, color: Colors.black54),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: _alerts.length,
                                itemBuilder: (context, index) {
                                  final alert = _alerts[index];
                                  final isWarning = (alert.valorRegistrado ?? 0) > 10;
                                  final hora = alert.criadoEm != null
                                      ? '${alert.criadoEm!.day}/${alert.criadoEm!.month} ${alert.criadoEm!.hour}:${alert.criadoEm!.minute.toString().padLeft(2, '0')}'
                                      : 'Hoje';

                                  bool showTimeText = false;
                                  if (index == 0) {
                                    showTimeText = true;
                                  } else {
                                    final prevAlert = _alerts[index - 1];
                                    final prevDay = prevAlert.criadoEm?.day;
                                    if (prevDay != alert.criadoEm?.day) showTimeText = true;
                                  }

                                  return AnimatedListItem(
                                    index: index,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (showTimeText)
                                          _buildTimeText(hora),
                                        TimelineCard(
                                          title: alert.tipo ?? 'Evento Registrado',
                                          location: 'Dispositivo: ${alert.idDispositivo?.substring(0, 8) ?? "N/D"}',
                                          time: hora,
                                          isAlert: isWarning,
                                          extraInfo: alert.status ?? 'Normal',
                                          icon: isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
                                          iconColor: isWarning ? const Color(0xFFC23147) : const Color(0xFF8DB600),
                                          iconBgColor: isWarning ? const Color(0xFFFFE5E5) : const Color(0xFFE5F5C9),
                                        ),
                                        if (index < _alerts.length - 1)
                                          _buildArrow(),
                                        if (index == _alerts.length - 1)
                                          const SizedBox(height: 24),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Row(
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
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC23147),
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
            _userRole.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),
        Builder(
          builder: (context) => GestureDetector(
            onTap: () => CustomEndDrawer.showMenu(context),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Image.asset(
                'assets/images/logo.png',
                color: const Color(0xFFC23147),
                width: 36,
                height: 36,
              ),
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
      // Frota
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

  Widget _buildTimeText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Icon(
          Icons.arrow_downward,
          color: Color(0xFFC23147),
          size: 20,
        ),
      ),
    );
  }
}

class TimelineCard extends StatelessWidget {
  final String title;
  final String location;
  final String time;
  final bool isAlert;
  final String? extraInfo;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const TimelineCard({
    super.key,
    required this.title,
    required this.location,
    required this.time,
    required this.isAlert,
    this.extraInfo,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                if (extraInfo != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Status: $extraInfo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isAlert ? const Color(0xFFC23147) : const Color(0xFF8DB600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
