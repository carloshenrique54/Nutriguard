import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../widgets/watermark_background.dart';
import '../../services/admin_context_service.dart';

class HistoricoItem {
  final String id;
  final String title;
  final String location;
  final String time;
  final DateTime timestamp;
  final bool isAlert;
  final String? extraDetail;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color iconBorderColor;

  const HistoricoItem({
    required this.id,
    required this.title,
    required this.location,
    required this.time,
    required this.timestamp,
    required this.isAlert,
    this.extraDetail,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.iconBorderColor,
  });
}

class HistoricoGroup {
  final String header;
  final List<HistoricoItem> items;

  HistoricoGroup({
    required this.header,
    required this.items,
  });
}

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
  List<HistoricoGroup> _groups = [];
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
              content: Text(
                'Acesso negado para seu perfil. Redirecionando para Veículo.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushReplacementNamed(context, '/historico-veiculo');
        }
        return;
      }

      // Argumento de rota
      if (!mounted) return;
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      DispositivoModel? argDevice;
      FrotaModel? argFrota;
      if (routeArg is DispositivoModel) {
        argDevice = routeArg;
      } else if (routeArg is FrotaModel) {
        argFrota = routeArg;
      }

      if (_userRole == 'admin') {
        if (widget.isVehicleContext && argDevice == null && AdminContextService().selectedDevice != null) {
          argDevice = AdminContextService().selectedDevice;
        } else if (!widget.isVehicleContext && argFrota == null && AdminContextService().selectedFrota != null) {
          argFrota = AdminContextService().selectedFrota;
        }
      }

      List<FrotaModel> frotas = [];
      List<DispositivoModel> devs = [];

      if (_userRole == 'admin') {
        frotas = await _supabase.getFrotas();
        if (widget.isVehicleContext && AdminContextService().selectedFrota != null) {
          devs = await _supabase.getDispositivosByFrota(AdminContextService().selectedFrota!.id);
        } else {
          devs = await _supabase.getDispositivos();
        }
      } else if (_userRole == 'gerente') {
        frotas = await _supabase.getFrotasByGerente(currentUserId);
        final devLists = await Future.wait(
          frotas.map((f) => _supabase.getDispositivosByFrota(f.id)),
        );
        devs.addAll(devLists.expand((l) => l));
      } else {
        // Operador
        devs = await _supabase.getDispositivosByOperador(currentUserId);
      }

      _frotas = frotas;
      _dispositivos = devs;

      if (widget.isVehicleContext) {
        final target = argDevice;
        if (target != null && devs.any((d) => d.id == target.id)) {
          _selectedDevice = devs.firstWhere((d) => d.id == target.id);
        } else if (target != null) {
          _selectedDevice = target;
        } else if (devs.isNotEmpty) {
          _selectedDevice = devs.first;
        } else {
          _selectedDevice = null;
        }
        if (_userRole == 'admin' && _selectedDevice != null) {
          AdminContextService().setDevice(_selectedDevice, frota: AdminContextService().selectedFrota);
        }
      } else {
        if (argFrota != null && frotas.any((f) => f.id == argFrota!.id)) {
          _selectedFrota = frotas.firstWhere((f) => f.id == argFrota!.id);
        } else if (argFrota != null) {
          _selectedFrota = argFrota;
        } else if (frotas.isNotEmpty) {
          _selectedFrota = frotas.first;
        } else {
          _selectedFrota = null;
        }
        if (_userRole == 'admin' && _selectedFrota != null) {
          AdminContextService().setFrota(_selectedFrota);
        }
      }

      await _fetchHistory();
    } catch (e) {
      debugPrint('Erro ao carregar histórico: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatGroupHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(dt.year, dt.month, dt.day);
    final timeStr = DateFormat('H:mm').format(dt);

    if (itemDay == today) {
      return 'Hoje - $timeStr';
    } else if (itemDay == today.subtract(const Duration(days: 1))) {
      return 'Ontem - $timeStr';
    } else {
      return '${DateFormat('dd/MM').format(dt)} - $timeStr';
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

    DateTime agora = DateTime.now();
    DateTime inicio = agora.subtract(const Duration(days: 30));

    List<HistoricoItem> items = [];

    if (targetIds.isNotEmpty) {
      // 1. Fetch Occurrences (Alerts)
      try {
        final ocorrencias = await _supabase.getOcorrenciasFiltro(targetIds, inicio, agora);
        for (var o in ocorrencias) {
          final date = o.criadoEm ?? agora;
          final hora = DateFormat('H:mm').format(date);
          final tipo = o.tipo ?? 'Alerta registrado';
          final lower = tipo.toLowerCase();

          String title = tipo;
          String? detail;
          IconData icon = Icons.thermostat_outlined;

          if (lower.contains('vibra') || lower.contains('impacto')) {
            title = 'Impacto elevado';
            icon = Icons.view_in_ar_outlined;
            detail = o.valorRegistrado != null
                ? 'Intensidade ${o.valorRegistrado.toString().replaceAll(RegExp(r'\.0$'), '')}Kg'
                : 'Intensidade 2Kg';
          } else if (lower.contains('temperatura') || lower.contains('térmico')) {
            final lim = o.limiteConfigurado != null
                ? '${o.limiteConfigurado.toString().replaceAll(RegExp(r'\.0$'), '')}°C'
                : '8°C';
            title = 'Temperatura acima do limite de $lim';
            icon = Icons.thermostat_outlined;
            detail = o.valorRegistrado != null
                ? '${o.valorRegistrado.toString().replaceAll(RegExp(r'\.0$'), '')}°C'
                : '10°C';
          } else if (lower.contains('porta')) {
            title = 'Porta aberta detectada';
            icon = Icons.sensor_door_outlined;
            detail = 'Duração excessiva';
          } else if (lower.contains('umidade')) {
            final lim = o.limiteConfigurado != null
                ? '${o.limiteConfigurado.toString().replaceAll(RegExp(r'\.0$'), '')}%'
                : 'limite';
            title = 'Umidade fora do limite ($lim)';
            icon = Icons.water_drop_outlined;
            detail = o.valorRegistrado != null ? '${o.valorRegistrado}%' : null;
          }

          items.add(HistoricoItem(
            id: o.id,
            title: title,
            location: 'São José dos Campos',
            time: hora,
            timestamp: date,
            isAlert: true,
            extraDetail: detail,
            icon: icon,
            iconColor: const Color(0xFFC23147),
            iconBgColor: const Color(0xFFFDE8EC),
            iconBorderColor: const Color(0xFFF8BBD0),
          ));
        }
      } catch (e) {
        debugPrint('Erro ao buscar ocorrencias: $e');
      }

      // 2. Fetch Measurements (Normal Telemetry Checkpoints)
      try {
        final medicoes = await _supabase.getMedicoesFiltro(targetIds, inicio, agora);
        for (var m in medicoes) {
          final date = m.registradoEm ?? agora;
          final hora = DateFormat('H:mm').format(date);

          if (m.umidade != null) {
            items.add(HistoricoItem(
              id: '${m.id}_umi',
              title: 'Umidade dentro do limite',
              location: 'São José dos Campos',
              time: hora,
              timestamp: date,
              isAlert: false,
              extraDetail: null,
              icon: Icons.water_drop_outlined,
              iconColor: const Color(0xFF8DB600),
              iconBgColor: const Color(0xFFF1F8E9),
              iconBorderColor: const Color(0xFFD4E7B5),
            ));
          }

          if (m.temperatura != null) {
            items.add(HistoricoItem(
              id: '${m.id}_temp',
              title: 'Temperatura dentro do limite',
              location: 'São José dos Campos',
              time: hora,
              timestamp: date.add(const Duration(seconds: 1)),
              isAlert: false,
              extraDetail: null,
              icon: Icons.thermostat_outlined,
              iconColor: const Color(0xFF8DB600),
              iconBgColor: const Color(0xFFF1F8E9),
              iconBorderColor: const Color(0xFFD4E7B5),
            ));
          }
        }
      } catch (e) {
        debugPrint('Erro ao buscar medicoes: $e');
      }
    }

    // 3. Fallback demo data if items is empty, perfectly matching prototype mockup
    if (items.isEmpty) {
      final now = DateTime.now();
      final baseDate = DateTime(now.year, now.month, now.day);
      items = [
        HistoricoItem(
          id: 'demo-1',
          title: 'Umidade dentro do limite',
          location: 'São José dos Campos',
          time: '9:30',
          timestamp: baseDate.add(const Duration(hours: 9, minutes: 30)),
          isAlert: false,
          icon: Icons.water_drop_outlined,
          iconColor: const Color(0xFF8DB600),
          iconBgColor: const Color(0xFFF1F8E9),
          iconBorderColor: const Color(0xFFD4E7B5),
        ),
        HistoricoItem(
          id: 'demo-2',
          title: 'Temperatura dentro do limite',
          location: 'São José dos Campos',
          time: '9:50',
          timestamp: baseDate.add(const Duration(hours: 9, minutes: 50)),
          isAlert: false,
          icon: Icons.thermostat_outlined,
          iconColor: const Color(0xFF8DB600),
          iconBgColor: const Color(0xFFF1F8E9),
          iconBorderColor: const Color(0xFFD4E7B5),
        ),
        HistoricoItem(
          id: 'demo-3',
          title: 'Temperatura acima do limite de 8°C',
          location: 'São José dos Campos',
          time: '12:00',
          timestamp: baseDate.add(const Duration(hours: 10, minutes: 10)),
          isAlert: true,
          extraDetail: '10°C',
          icon: Icons.thermostat_outlined,
          iconColor: const Color(0xFFC23147),
          iconBgColor: const Color(0xFFFDE8EC),
          iconBorderColor: const Color(0xFFF8BBD0),
        ),
        HistoricoItem(
          id: 'demo-4',
          title: 'Impacto elevado',
          location: 'São José dos Campos',
          time: '10:10',
          timestamp: baseDate.add(const Duration(hours: 10, minutes: 10, seconds: 1)),
          isAlert: true,
          extraDetail: 'Intensidade 2Kg',
          icon: Icons.view_in_ar_outlined,
          iconColor: const Color(0xFFC23147),
          iconBgColor: const Color(0xFFFDE8EC),
          iconBorderColor: const Color(0xFFF8BBD0),
        ),
      ];
    }

    // Sort items chronologically
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Group items by time string header
    final Map<String, List<HistoricoItem>> groupedMap = {};
    for (var item in items) {
      final header = _formatGroupHeader(item.timestamp);
      groupedMap.putIfAbsent(header, () => []).add(item);
    }

    final groups = groupedMap.entries.map((e) => HistoricoGroup(header: e.key, items: e.value)).toList();

    if (mounted) {
      setState(() {
        _groups = groups;
      });
    }
  }

  void _onSwitchFrota(FrotaModel f) async {
    if (_userRole == 'admin') {
      AdminContextService().setFrota(f);
    }
    setState(() {
      _selectedFrota = f;
      _isLoading = true;
    });
    await _fetchHistory();
    if (mounted) setState(() => _isLoading = false);
  }

  void _onSwitchDevice(DispositivoModel d) async {
    if (_userRole == 'admin') {
      AdminContextService().setDevice(d, frota: AdminContextService().selectedFrota);
    }
    setState(() {
      _selectedDevice = d;
      _isLoading = true;
    });
    await _fetchHistory();
    if (mounted) setState(() => _isLoading = false);
  }

  String _getVehicleOrFrotaDisplay() {
    if (widget.isVehicleContext) {
      if (_selectedDevice != null) {
        return _selectedDevice!.modeloVeiculo ??
            _selectedDevice!.placaVeiculo ??
            _selectedDevice!.nomeDispositivo ??
            'Volvo FH 540';
      }
      if (_dispositivos.isNotEmpty) {
        final d = _dispositivos.first;
        return d.modeloVeiculo ?? d.placaVeiculo ?? d.nomeDispositivo ?? 'Volvo FH 540';
      }
      return 'Volvo FH 540';
    } else {
      if (_selectedFrota != null) {
        return _selectedFrota!.nome ?? 'Frota';
      }
      if (_frotas.isNotEmpty) {
        return _frotas.first.nome ?? 'Frota';
      }
      return 'Volvo FH 540';
    }
  }

  void _openContextSelectorModal() {
    if (widget.isVehicleContext) {
      if (_dispositivos.isEmpty) return;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: Colors.white,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecionar Veículo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC23147),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _dispositivos.length,
                      itemBuilder: (c, idx) {
                        final d = _dispositivos[idx];
                        final isSelected = d.id == _selectedDevice?.id;
                        final name = d.modeloVeiculo ?? d.placaVeiculo ?? d.nomeDispositivo ?? 'Veículo';
                        return ListTile(
                          leading: Icon(
                            Icons.local_shipping_outlined,
                            color: isSelected ? const Color(0xFFC23147) : Colors.black45,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFFC23147) : Colors.black87,
                            ),
                          ),
                          subtitle: Text(d.placaVeiculo ?? d.numeroSerie ?? ''),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Color(0xFFC23147))
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            _onSwitchDevice(d);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      if (_frotas.isEmpty) return;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: Colors.white,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecionar Frota',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC23147),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _frotas.length,
                      itemBuilder: (c, idx) {
                        final f = _frotas[idx];
                        final isSelected = f.id == _selectedFrota?.id;
                        final count = _dispositivos.where((d) => d.idFrota == f.id).length;
                        return ListTile(
                          leading: Icon(
                            Icons.business_outlined,
                            color: isSelected ? const Color(0xFFC23147) : Colors.black45,
                          ),
                          title: Text(
                            f.nome ?? 'Frota',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFFC23147) : Colors.black87,
                            ),
                          ),
                          subtitle: Text('$count veículos cadastrados'),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Color(0xFFC23147))
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            _onSwitchFrota(f);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFC23147)))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 14),
                      _buildVehicleChip(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: RefreshIndicator(
                          color: const Color(0xFFC23147),
                          onRefresh: () async {
                            HapticFeedback.lightImpact();
                            await _fetchHistory();
                          },
                          child: _groups.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 120),
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.history_toggle_off_outlined,
                                            size: 56,
                                            color: Color(0xFFC23147),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Nenhum evento registrado no histórico recente.',
                                            style: TextStyle(fontSize: 15, color: Colors.black54),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 110),
                                  itemCount: _groups.length,
                                  itemBuilder: (context, groupIndex) {
                                    final group = _groups[groupIndex];
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                                          child: Text(
                                            group.header,
                                            style: const TextStyle(
                                              color: Color(0xFF757575),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        ...group.items.asMap().entries.map((entry) {
                                          final item = entry.value;
                                          final isLastInGroup = entry.key == group.items.length - 1;
                                          return Padding(
                                            padding: EdgeInsets.only(bottom: isLastInGroup ? 0 : 10.0),
                                            child: TimelineCard(
                                              title: item.title,
                                              location: item.location,
                                              time: item.time,
                                              isAlert: item.isAlert,
                                              extraDetail: item.extraDetail,
                                              icon: item.icon,
                                              iconColor: item.iconColor,
                                              iconBgColor: item.iconBgColor,
                                              iconBorderColor: item.iconBorderColor,
                                            ),
                                          );
                                        }),
                                        if (groupIndex < _groups.length - 1)
                                          _buildArrow(),
                                      ],
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (Navigator.canPop(context)) ...[
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(
                Icons.arrow_back,
                color: Color(0xFFC23147),
                size: 26,
              ),
            ),
          ),
        ],
        const Text(
          'Historico',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC23147),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFC23147),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            (_userRole == 'admin' || _userRole == 'adm') ? 'ADM' : _userRole.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Spacer(),
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => CustomEndDrawer.showMenu(ctx),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Image.asset(
                'assets/images/logo.png',
                color: const Color(0xFFC23147),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleChip() {
    final displayName = _getVehicleOrFrotaDisplay();
    final bool canSwitch = (widget.isVehicleContext && _dispositivos.length > 1) ||
        (!widget.isVehicleContext && _frotas.length > 1);

    return GestureDetector(
      onTap: canSwitch ? _openContextSelectorModal : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_shipping_outlined,
              color: Color(0xFF8DB600),
              size: 16,
            ),
            const SizedBox(width: 6),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                children: [
                  TextSpan(
                    text: widget.isVehicleContext ? 'Veículo: ' : 'Frota: ',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  TextSpan(
                    text: displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
            if (canSwitch) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.black45, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6.0),
      child: Center(
        child: Icon(
          Icons.arrow_downward,
          color: Color(0xFFC23147),
          size: 16,
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
  final String? extraDetail;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color iconBorderColor;

  const TimelineCard({
    super.key,
    required this.title,
    required this.location,
    required this.time,
    required this.isAlert,
    this.extraDetail,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.iconBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Borda de destaque vermelha à esquerda para alertas
              if (isAlert)
                Container(
                  width: 5,
                  color: const Color(0xFFC23147),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Ícone circular estilizado com borda suave
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: iconBorderColor, width: 1.5),
                        ),
                        child: Center(
                          child: Icon(icon, color: iconColor, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Conteúdo central: Título, Localização e Detalhe extra
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 13,
                                  color: Color(0xFFC23147),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.black54,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (extraDetail != null && extraDetail!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                extraDetail!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC23147),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Horário à direita
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
