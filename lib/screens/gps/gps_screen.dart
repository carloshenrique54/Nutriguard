import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';

class GpsScreen extends StatefulWidget {
  final String userRole;

  const GpsScreen({
    super.key,
    this.userRole = 'Operador',
  });

  @override
  State<GpsScreen> createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  bool _isPanelExpanded = false;
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  
  List<DispositivoModel> _dispositivos = [];
  Map<String, MedicaoModel> _latestMedicoes = {};
  DispositivoModel? _selectedDevice;
  Timer? _timer;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _refreshLocations();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.currentUser;
      if (user != null) {
        final perfil = await _supabase.getUsuarioPerfil(user.id);
        if (perfil != null) {
          if (perfil.role == 'admin' || perfil.role == 'gerente') {
            List<FrotaModel> frotas = perfil.role == 'admin' 
              ? await _supabase.getFrotas()
              : await _supabase.getFrotasByGerente(perfil.id);
            for (var f in frotas) {
              final devs = await _supabase.getDispositivosByFrota(f.id);
              _dispositivos.addAll(devs);
            }
          } else {
            _dispositivos = await _supabase.getDispositivosByOperador(perfil.id);
          }
        }
      }
      
      await _refreshLocations();
    } catch (e) {
      debugPrint('Erro GPS: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshLocations() async {
    if (_dispositivos.isEmpty) return;
    try {
      List<String> ids = _dispositivos.map((d) => d.id).toList();
      DateTime agora = DateTime.now();
      DateTime inicio = agora.subtract(const Duration(days: 7));
      
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
      
      if (mounted) {
        setState(() {
          _latestMedicoes = latest;
        });
      }
    } catch (e) {
      debugPrint('Erro atualizar location: $e');
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
      
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 4),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildHeader(context),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 90.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFC8E569), width: 4),
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFC23147)))
                      : Stack(
                    children: [
                      // Camada 1: O Mapa Interativo
                      _buildMapBackground(),
                      
                      // Camada 2: Barra de Pesquisa (Topo)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 70, // Espaço para os botões da direita
                        child: _buildSearchBar(),
                      ),

                      // Camada 3: Botões Flutuantes
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _buildMapActionButtons(),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        bottom: _isPanelExpanded ? 240 : 120, // Move dinamicamente
                        right: 16,
                        child: _buildFullscreenButton(),
                      ),

                      // Camada 4: Painel Inferior Premium
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Text(
          'GPS',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC23147),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFC23147),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.userRole,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => CustomEndDrawer.showMenu(context),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'assets/images/logo.png',
                errorBuilder: (ctx, error, stackTrace) =>
                    const Icon(Icons.local_shipping_outlined, color: Color(0xFFC23147), size: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapBackground() {
    List<Marker> markers = [];
    for (var d in _dispositivos) {
      var m = _latestMedicoes[d.id];
      if (m != null && m.latitude != null && m.longitude != null) {
        bool isSelected = _selectedDevice?.id == d.id;
        markers.add(
          Marker(
            point: LatLng(m.latitude!.toDouble(), m.longitude!.toDouble()),
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDevice = d;
                  _isPanelExpanded = true;
                });
                _mapController.move(LatLng(m.latitude!.toDouble(), m.longitude!.toDouble()), 16.0);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFC23147) : const Color(0xFFC8E569),
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
                      Icons.local_shipping, 
                      color: isSelected ? Colors.white : Colors.black87, 
                      size: isSelected ? 24 : 20
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)
                      ]
                    ),
                    child: Text(
                      d.placaVeiculo ?? d.nomeDispositivo ?? 'Veículo', 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFFC23147) : Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(-23.2237, -45.9009),
        initialZoom: 12.0,
        onTap: (tapPosition, point) {
          setState(() {
            _selectedDevice = null;
            _isPanelExpanded = false;
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.nutriguard',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFFC23147), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pesquisar rotas, veículos...',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, color: Colors.black54, size: 18),
              ),
            ],
          ),
        ),
      ),
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
            icon: const Icon(Icons.near_me_outlined, color: Colors.black87, size: 22),
            onPressed: () {
              if (_selectedDevice != null && _latestMedicoes.containsKey(_selectedDevice!.id)) {
                var m = _latestMedicoes[_selectedDevice!.id]!;
                _mapController.move(LatLng(m.latitude!.toDouble(), m.longitude!.toDouble()), 16.0);
              } else if (_latestMedicoes.isNotEmpty) {
                var m = _latestMedicoes.values.first;
                _mapController.move(LatLng(m.latitude!.toDouble(), m.longitude!.toDouble()), 12.0);
              }
            },
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFC23147),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC23147).withAlpha(80),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.crop_free, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    if (_selectedDevice == null) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, -3))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text("Selecione um veículo no mapa", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    var m = _latestMedicoes[_selectedDevice!.id];
    String statusStr = 'Desconhecido';
    Color statusColor = Colors.grey;
    String lastUpdateStr = '--';
    String tempStr = '--';
    
    if (m != null && m.registradoEm != null) {
      bool isRecent = DateTime.now().difference(m.registradoEm!).inHours < 2;
      statusStr = isRecent ? 'Em Trânsito' : 'Offline / Parado';
      statusColor = isRecent ? const Color(0xFFC23147) : Colors.black45;
      lastUpdateStr = '${m.registradoEm!.day}/${m.registradoEm!.month} ${m.registradoEm!.hour}:${m.registradoEm!.minute.toString().padLeft(2,'0')}';
      if (m.temperatura != null) {
        tempStr = '${m.temperatura!.toStringAsFixed(1)}°C';
      }
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                padding: const EdgeInsets.only(bottom: 12.0),
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
                  color: const Color(0xFFC8E569).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping, color: Color(0xFF8DC63F), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDevice!.placaVeiculo ?? _selectedDevice!.nomeDispositivo ?? 'Dispositivo',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusStr,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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
                      _buildQuickMetric(Icons.battery_charging_full, 'Bateria', m?.bateria != null ? '${m!.bateria}%' : '--'),
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
                        icon: Icons.history,
                        label: 'Histórico',
                        color: Colors.grey.shade100,
                        textColor: Colors.black87,
                        iconColor: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.assignment_outlined,
                        label: 'Relatório',
                        color: const Color(0xFFC8E569),
                        textColor: Colors.black87,
                        iconColor: Colors.black87,
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
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required Color iconColor,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {},
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
