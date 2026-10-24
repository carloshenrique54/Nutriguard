import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/supabase_service.dart';
import '../../services/trip_service.dart';
import '../../models/models.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/admin_context_service.dart';

class GpsScreen extends StatefulWidget {
  final DispositivoModel? initialDevice;
  final SupabaseService? supabaseService;
  final TripService? tripService;

  const GpsScreen({
    super.key,
    this.initialDevice,
    this.supabaseService,
    this.tripService,
  });

  @override
  State<GpsScreen> createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  bool _isPanelExpanded = false;
  late final SupabaseService _supabase;
  late final TripService _tripService;
  bool _isLoading = true;
  String _userRole = '';
  
  List<DispositivoModel> _dispositivos = [];
  Map<String, MedicaoModel> _latestMedicoes = {};
  Set<String> _devicesInTrip = {};
  TripInfo? _selectedTripInfo;
  DispositivoModel? _selectedDevice;
  Timer? _timer;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseService ?? SupabaseService();
    _tripService = widget.tripService ?? TripService();
    _tripService.tripStateNotifier.addListener(_onTripStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshLocations();
    });
  }

  @override
  void dispose() {
    _tripService.tripStateNotifier.removeListener(_onTripStateChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _onTripStateChanged() {
    if (mounted) {
      _updateTripStatus();
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.currentUser;
      if (user == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final perfil = await _supabase.getUsuarioPerfil(user.id);
      _userRole = perfil?.role ?? '';

      // Obter argumento de rota se houver
      if (!mounted) return;
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      DispositivoModel? argDevice;
      if (routeArg is DispositivoModel) {
        argDevice = routeArg;
      } else if (widget.initialDevice != null) {
        argDevice = widget.initialDevice;
      } else if ((_userRole == 'admin' || _userRole == 'adm') && AdminContextService().hasDevice) {
        argDevice = AdminContextService().selectedDevice;
      }

      // Buscar veículos de acordo com a matriz de permissões
      List<DispositivoModel> devs = [];
      if (_userRole == 'admin') {
        devs = await _supabase.getDispositivos();
      } else if (_userRole == 'gerente') {
        final frotas = await _supabase.getFrotasByGerente(user.id);
        for (var f in frotas) {
          final fleetDevs = await _supabase.getDispositivosByFrota(f.id);
          devs.addAll(fleetDevs);
        }
      } else {
        // Operador
        devs = await _supabase.getDispositivosByOperador(user.id);
      }

      _dispositivos = devs;

      // Definir o veículo selecionado
      final target = argDevice;
      if (target != null && devs.any((d) => d.id == target.id)) {
        _selectedDevice = devs.firstWhere((d) => d.id == target.id);
      } else if (_userRole == 'operador' && devs.isNotEmpty) {
        // Operador tem acesso apenas ao seu próprio veículo
        _selectedDevice = devs.first;
      } else if (devs.length == 1) {
        _selectedDevice = devs.first;
      } else {
        // Múltiplos veículos e nenhum selecionado previamente
        _selectedDevice = null;
      }

      await _refreshLocations();

      // Se temos um veículo selecionado com posição, focar nele no mapa
      if (_selectedDevice != null && _latestMedicoes.containsKey(_selectedDevice!.id)) {
        final m = _latestMedicoes[_selectedDevice!.id]!;
        if (m.latitude != null && m.longitude != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(LatLng(m.latitude!.toDouble(), m.longitude!.toDouble()), 15.0);
          });
        }
      }
    } catch (e) {
      debugPrint('Erro GPS: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTripStatus() async {
    try {
      final user = _supabase.currentUser;
      final currentUserId = user?.id ?? '';
      final Set<String> inTrip = {};

      for (final d in _dispositivos) {
        final active = await _tripService.isDeviceInTrip(d.id, operatorId: d.idOperador);
        if (active) inTrip.add(d.id);
      }

      TripInfo? trip;
      if (_selectedDevice != null) {
        trip = await _tripService.getActiveTripByDevice(
          _selectedDevice!.id,
          operatorId: _selectedDevice!.idOperador ?? currentUserId,
        );
      }

      if (trip == null && _userRole == 'operador' && currentUserId.isNotEmpty) {
        trip = await _tripService.getActiveTrip(currentUserId);
        if (trip != null && _selectedDevice != null) {
          inTrip.add(_selectedDevice!.id);
        }
      }

      if (mounted) {
        setState(() {
          _devicesInTrip = inTrip;
          _selectedTripInfo = trip;
        });
      }
    } catch (e) {
      debugPrint('Erro ao atualizar status de viagem no GPS: $e');
    }
  }

  Future<void> _refreshLocations() async {
    if (_dispositivos.isEmpty) return;
    try {
      List<String> ids = _dispositivos.map((d) => d.id).toList();
      DateTime agora = DateTime.now();
      DateTime inicio = agora.subtract(const Duration(days: 30));
      
      final medicoes = await _supabase.getMedicoesFiltro(ids, inicio, agora);
      
      Map<String, MedicaoModel> latest = {};
      for (var m in medicoes) {
        if (m.latitude != null && m.longitude != null && m.idDispositivo != null) {
          if (!latest.containsKey(m.idDispositivo)) {
            latest[m.idDispositivo!] = m;
          } else {
            if (m.registradoEm!.isAfter(latest[m.idDispositivo!]!.registradoEm!)) {
              latest[m.idDispositivo!] = m;
            }
          }
        }
      }

      // Fallback: se algum dispositivo não tiver sido capturado no filtro, busca última medição direta
      for (var d in _dispositivos) {
        if (!latest.containsKey(d.id)) {
          final mDirect = await _supabase.getLatestMedicao(d.id);
          if (mDirect != null && mDirect.latitude != null && mDirect.longitude != null) {
            latest[d.id] = mDirect;
          }
        }
      }

      await _updateTripStatus();
      
      if (mounted) {
        setState(() {
          _latestMedicoes = latest;
        });
      }
    } catch (e) {
      debugPrint('Erro atualizar location: $e');
    }
  }

  void _onSelectVehicle(DispositivoModel device) {
    setState(() {
      _selectedDevice = device;
      _isPanelExpanded = true;
    });

    _updateTripStatus();

    if (_latestMedicoes.containsKey(device.id)) {
      final m = _latestMedicoes[device.id]!;
      if (m.latitude != null && m.longitude != null) {
        _mapController.move(LatLng(m.latitude!.toDouble(), m.longitude!.toDouble()), 16.0);
      }
    } else {
      _supabase.getLatestMedicao(device.id).then((m) {
        if (m != null && m.latitude != null && m.longitude != null && mounted) {
          setState(() {
            _latestMedicoes[device.id] = m;
          });
          _mapController.move(LatLng(m.latitude!.toDouble(), m.longitude!.toDouble()), 16.0);
        }
      });
    }
  }

  void _togglePanel() {
    setState(() {
      _isPanelExpanded = !_isPanelExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 4,
        isVehicleContext: true,
        currentDevice: _selectedDevice,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildHeader(context),
            ),
            if (_selectedDevice != null && _dispositivos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: _buildVehicleSelector(),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFC23147)))
                  : _dispositivos.isEmpty
                      ? _buildEmptyState()
                      : _selectedDevice == null
                          ? _buildSelectVehicleState()
                          : Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 90.0, top: 8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFC8E569), width: 3),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFC8E569).withAlpha(40),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    // Camada 1: O Mapa
                                    _buildMapBackground(),
                                    
                                    // Camada 2: Botões Flutuantes
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: _buildMapActionButtons(),
                                    ),

                                    // Camada 3: Painel Inferior do Veículo
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: _buildBottomPanel(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectVehicleState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC8E569), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: const [
                Icon(Icons.location_searching, size: 56, color: Color(0xFFC23147)),
                SizedBox(height: 12),
                Text(
                  'Nenhum veículo selecionado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'A tela de GPS está vinculada a um veículo específico para exibir sua localização e telemetria em tempo real. Escolha um dos veículos autorizados abaixo para rastrear no mapa:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Selecione um veículo:',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          ..._dispositivos.map((d) {
            final hasLocation = _latestMedicoes.containsKey(d.id) &&
                _latestMedicoes[d.id]?.latitude != null &&
                _latestMedicoes[d.id]?.longitude != null;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFC8E569),
                    child: Icon(Icons.directions_car, color: Colors.black87),
                  ),
                  title: Text(
                    d.placaVeiculo ?? d.nomeDispositivo ?? 'Veículo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${d.modeloVeiculo ?? "Dispositivo"} • ${hasLocation ? "Sinal GPS ativo" : "Sem sinal recente"}',
                    style: TextStyle(fontSize: 12, color: hasLocation ? Colors.green[700] : Colors.black54),
                  ),
                  trailing: ElevatedButton.icon(
                    onPressed: () => _onSelectVehicle(d),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC23147),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.map, size: 16, color: Colors.white),
                    label: const Text('Rastrear', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard-veiculo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFFC23147)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.dashboard_outlined, color: Color(0xFFC23147)),
            label: const Text('Ir para Dashboard de Veículos', style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isAdmin = _userRole == 'admin';
    final bool isGerente = _userRole == 'gerente';

    String title;
    String desc;

    if (isAdmin) {
      title = 'Nenhum veículo cadastrado';
      desc = 'Não há veículos cadastrados para exibição no GPS.';
    } else if (isGerente) {
      title = 'Nenhum veículo na frota';
      desc = 'Sua frota não possui veículos associados no momento. A configuração depende do Administrador.';
    } else {
      title = 'Nenhum veículo associado';
      desc = 'Você não possui nenhum veículo associado ao seu usuário de operador. A configuração depende do Administrador.';
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_outlined, size: 64, color: Color(0xFFC23147)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black54), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (isAdmin)
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/cadastrar-dispositivo').then((_) => _fetchData()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC23147),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Cadastrar dispositivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Flexible(
          child: Text(
            'GPS — Veículo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC23147),
            ),
            overflow: TextOverflow.ellipsis,
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
            (_userRole == 'admin' || _userRole == 'adm') ? 'ADM' : _userRole.toUpperCase(),
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

  Widget _buildVehicleSelector() {
    // Operador: acesso estrito ao próprio veículo, sem seletor.
    final bool isOperador = _userRole == 'operador';
    final d = _selectedDevice ?? (_dispositivos.isNotEmpty ? _dispositivos.first : null);
    if (d == null) return const SizedBox.shrink();

    final bool isSelectedInTrip = _devicesInTrip.contains(d.id) ||
        (isOperador && _selectedTripInfo != null);

    if (isOperador || _dispositivos.length <= 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Icon(
              isSelectedInTrip ? Icons.navigation_rounded : Icons.directions_car,
              color: isSelectedInTrip ? const Color(0xFF2E7D32) : const Color(0xFF8DB600),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Veículo: ${d.placaVeiculo ?? d.nomeDispositivo ?? "Dispositivo"}${isSelectedInTrip ? " • Em viagem" : ""}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelectedInTrip)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF81C784)),
                ),
                child: const Text(
                  'Em viagem',
                  style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DispositivoModel>(
          value: _selectedDevice,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC23147)),
          items: _dispositivos.map((d) {
            final devInTrip = _devicesInTrip.contains(d.id);
            return DropdownMenuItem<DispositivoModel>(
              value: d,
              child: Row(
                children: [
                  Icon(
                    devInTrip ? Icons.navigation_rounded : Icons.directions_car,
                    color: devInTrip ? const Color(0xFF2E7D32) : const Color(0xFF8DB600),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    d.placaVeiculo ?? d.nomeDispositivo ?? 'Veículo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (d.modeloVeiculo != null) ...[
                    const SizedBox(width: 6),
                    Text('(${d.modeloVeiculo})', style: const TextStyle(color: Colors.black54, fontSize: 11)),
                  ],
                  if (devInTrip) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Em viagem',
                        style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) _onSelectVehicle(val);
          },
        ),
      ),
    );
  }

  Widget _buildMapBackground() {
    List<Marker> markers = [];
    final bool isSelectedInTrip = _selectedDevice != null && (
      _devicesInTrip.contains(_selectedDevice!.id) ||
      (_userRole == 'operador' && _selectedTripInfo != null)
    );

    for (var d in _dispositivos) {
      var m = _latestMedicoes[d.id];
      if (m != null && m.latitude != null && m.longitude != null) {
        bool isSelected = _selectedDevice?.id == d.id;
        bool devInTrip = _devicesInTrip.contains(d.id) || (isSelected && isSelectedInTrip);

        markers.add(
          Marker(
            point: LatLng(m.latitude!.toDouble(), m.longitude!.toDouble()),
            width: 85,
            height: 85,
            child: GestureDetector(
              onTap: () => _onSelectVehicle(d),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFFC23147) 
                          : (devInTrip ? const Color(0xFF2E7D32) : const Color(0xFFC8E569)),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Icon(
                      devInTrip ? Icons.navigation_rounded : Icons.local_shipping,
                      color: (isSelected || devInTrip) ? Colors.white : Colors.black87,
                      size: isSelected ? 24 : 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (devInTrip)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            d.placaVeiculo ?? d.nomeDispositivo ?? 'Veículo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFFC23147) : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      }
    }

    // Traçado da rota e marcador de destino se houver viagem ativa com coordenadas
    List<Polyline> polylines = [];
    if (isSelectedInTrip && _selectedTripInfo != null &&
        _selectedTripInfo!.destinationLatitude != null &&
        _selectedTripInfo!.destinationLongitude != null) {
      final destLatLng = LatLng(
        _selectedTripInfo!.destinationLatitude!,
        _selectedTripInfo!.destinationLongitude!,
      );

      markers.add(
        Marker(
          point: destLatLng,
          width: 90,
          height: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFC23147),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                ),
                child: Text(
                  _selectedTripInfo!.destination,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC23147),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );

      var currentMed = _latestMedicoes[_selectedDevice!.id];
      if (currentMed != null && currentMed.latitude != null && currentMed.longitude != null) {
        polylines.add(
          Polyline(
            points: [
              LatLng(currentMed.latitude!.toDouble(), currentMed.longitude!.toDouble()),
              destLatLng,
            ],
            strokeWidth: 4.0,
            color: const Color(0xFFC23147),
          ),
        );
      }
    }

    // Posição inicial: se tiver veículo selecionado com medição, centraliza nele, senão default
    LatLng initialPos = const LatLng(-23.2237, -45.9009);
    if (_selectedDevice != null && _latestMedicoes.containsKey(_selectedDevice!.id)) {
      final m = _latestMedicoes[_selectedDevice!.id]!;
      if (m.latitude != null && m.longitude != null) {
        initialPos = LatLng(m.latitude!.toDouble(), m.longitude!.toDouble());
      }
    } else if (isSelectedInTrip && _selectedTripInfo?.destinationLatitude != null && _selectedTripInfo?.destinationLongitude != null) {
      initialPos = LatLng(_selectedTripInfo!.destinationLatitude!, _selectedTripInfo!.destinationLongitude!);
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialPos,
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.nutriguard',
        ),
        if (polylines.isNotEmpty)
          PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildMapActionButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87, size: 22),
            onPressed: () => _refreshLocations(),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.zero,
          ),
          Divider(color: Colors.grey.shade200, height: 1, indent: 8, endIndent: 8),
          IconButton(
            icon: const Icon(Icons.my_location, color: Color(0xFFC23147), size: 22),
            onPressed: () {
              if (_selectedDevice != null && _latestMedicoes.containsKey(_selectedDevice!.id)) {
                var m = _latestMedicoes[_selectedDevice!.id]!;
                if (m.latitude != null && m.longitude != null) {
                  _mapController.move(LatLng(m.latitude!.toDouble(), m.longitude!.toDouble()), 16.0);
                }
              }
            },
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    if (_selectedDevice == null) {
      return const SizedBox.shrink();
    }

    var m = _latestMedicoes[_selectedDevice!.id];
    final bool isInTrip = _selectedDevice != null && (
      _devicesInTrip.contains(_selectedDevice!.id) ||
      (_userRole == 'operador' && _selectedTripInfo != null)
    );

    String statusStr;
    Color statusColor;
    String lastUpdateStr = '--';
    String tempStr = '--';
    
    if (m != null && m.registradoEm != null) {
      lastUpdateStr = '${m.registradoEm!.day.toString().padLeft(2, '0')}/${m.registradoEm!.month.toString().padLeft(2, '0')} ${m.registradoEm!.hour.toString().padLeft(2, '0')}:${m.registradoEm!.minute.toString().padLeft(2, '0')}';
      if (m.temperatura != null) {
        tempStr = '${m.temperatura!.toStringAsFixed(1)}°C';
      }
    }

    if (isInTrip) {
      statusStr = 'Em trânsito';
      statusColor = const Color(0xFF2E7D32);
    } else if (m != null && m.registradoEm != null) {
      bool isRecent = DateTime.now().difference(m.registradoEm!).inHours < 2;
      statusStr = isRecent ? 'Parado' : 'Parado / Offline';
      statusColor = isRecent ? const Color(0xFF1565C0) : Colors.black45;
    } else {
      statusStr = 'Sem sinal';
      statusColor = Colors.grey;
    }

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 0 && _isPanelExpanded) {
          _togglePanel();
        } else if (details.primaryVelocity! < 0 && !_isPanelExpanded) {
          _togglePanel();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _togglePanel,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
            
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isInTrip ? const Color(0xFFE8F5E9) : const Color(0xFFC8E569).withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isInTrip ? Icons.navigation_rounded : Icons.local_shipping,
                    color: isInTrip ? const Color(0xFF2E7D32) : const Color(0xFF8DC63F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedDevice!.placaVeiculo ?? _selectedDevice!.nomeDispositivo ?? 'Veículo',
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (isInTrip && _selectedTripInfo != null && _selectedTripInfo!.destination.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.navigation_rounded, color: Color(0xFF2E7D32), size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Destino: ${_selectedTripInfo!.destination}',
                                style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.black54, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Último sinal: $lastUpdateStr',
                            style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isInTrip) ...[
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Text(
                        statusStr,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isPanelExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  if (isInTrip && _selectedTripInfo != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.route_rounded, color: Color(0xFF2E7D32), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Viagem em andamento para ${_selectedTripInfo!.destination}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF2E7D32),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Iniciada em ${_selectedTripInfo!.startedAt.hour.toString().padLeft(2, '0')}:${_selectedTripInfo!.startedAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickMetric(Icons.thermostat, 'Temp', tempStr),
                        Container(width: 1, height: 24, color: Colors.grey.shade300),
                        _buildQuickMetric(Icons.battery_charging_full, 'Bateria', m?.bateria != null ? '${m!.bateria!.toStringAsFixed(0)}%' : '--'),
                        Container(width: 1, height: 24, color: Colors.grey.shade300),
                        _buildQuickMetric(Icons.door_front_door_outlined, 'Porta', m?.portaAberta == true ? 'Aberta' : (m?.portaAberta == false ? 'Fechada' : '--')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.dashboard_outlined,
                          label: 'Ver no Dashboard',
                          color: const Color(0xFFC8E569),
                          textColor: Colors.black87,
                          iconColor: Colors.black87,
                          onTap: () {
                            Navigator.pushNamed(context, '/dashboard-veiculo', arguments: _selectedDevice);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_userRole == 'operador' && isInTrip)
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.stop_circle_outlined,
                            label: 'Parar Viagem',
                            color: const Color(0xFFFFEBEE),
                            textColor: const Color(0xFFC23147),
                            iconColor: const Color(0xFFC23147),
                            onTap: () async {
                              final res = await Navigator.pushNamed(context, '/parar-viagem');
                              if (res == true && mounted) {
                                _fetchData();
                              }
                            },
                          ),
                        )
                      else
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.description_outlined,
                            label: 'Relatório',
                            color: Colors.grey.shade100,
                            textColor: Colors.black87,
                            iconColor: Colors.black54,
                            onTap: () {
                              Navigator.pushNamed(context, '/relatorios-veiculo');
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMetric(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 10)),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
