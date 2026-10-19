import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../widgets/watermark_background.dart';
import '../../widgets/responsive_layout.dart';

class IniciarViagemScreen extends StatefulWidget {
  final DispositivoModel? initialDevice;
  final UsuarioModel? initialUser;

  const IniciarViagemScreen({
    super.key,
    this.initialDevice,
    this.initialUser,
  });

  @override
  State<IniciarViagemScreen> createState() => _IniciarViagemScreenState();
}

class _IniciarViagemScreenState extends State<IniciarViagemScreen> {
  final SupabaseService _supabase = SupabaseService();
  final TripService _tripService = TripService();
  final TextEditingController _destinoCtrl = TextEditingController();
  final TextEditingController _obsCtrl = TextEditingController();
  final MapController _mapController = MapController();

  bool _isLoading = true;
  bool _isStarting = false;
  bool _isGeocoding = false;
  double _mapZoom = 12.0;
  UsuarioModel? _perfil;
  DispositivoModel? _dispositivo;
  TripInfo? _activeTrip;
  LatLng? _originLatLng;
  LatLng? _destinationLatLng;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _destinoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      if (widget.initialDevice != null) {
        _dispositivo = widget.initialDevice;
      }
      if (widget.initialUser != null) {
        _perfil = widget.initialUser;
      }

      final user = _supabase.currentUser;
      final targetId = _perfil?.id ?? user?.id;

      if (user != null && _perfil == null) {
        try {
          final perfil = await _supabase.getUsuarioPerfil(user.id);
          _perfil = perfil;
        } catch (_) {}
      }

      if (targetId != null && targetId.isNotEmpty) {
        if (_dispositivo == null) {
          try {
            final devices = await _supabase.getDispositivosByOperador(targetId);
            if (devices.isNotEmpty) {
              _dispositivo = devices.first;
            }
          } catch (_) {}
        }

        // Carregar posição GPS mais recente do veículo
        if (_dispositivo != null) {
          try {
            final latestMed = await _supabase.getLatestMedicao(_dispositivo!.id);
            if (latestMed?.latitude != null && latestMed?.longitude != null) {
              _originLatLng = LatLng(latestMed!.latitude!.toDouble(), latestMed.longitude!.toDouble());
            }
          } catch (_) {}
        }

        // Checar se já tem viagem ativa
        try {
          final activeTrip = await _tripService.getActiveTrip(targetId);
          _activeTrip = activeTrip;
          if (activeTrip != null && activeTrip.destinationLatitude != null && activeTrip.destinationLongitude != null) {
            _destinationLatLng = LatLng(activeTrip.destinationLatitude!, activeTrip.destinationLongitude!);
            _destinoCtrl.text = activeTrip.destination;
          }
        } catch (_) {}
      }

      _originLatLng ??= const LatLng(-23.5505, -46.6333); // Padrão Hub Central SP
    } catch (e) {
      debugPrint('Erro ao carregar dados do operador em iniciar_viagem: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectDestinationPoint(LatLng point, {String? label}) {
    setState(() {
      _destinationLatLng = point;
      if (label != null && label.isNotEmpty) {
        _destinoCtrl.text = label;
      } else {
        _destinoCtrl.text = 'Destino (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
      }
    });

    try {
      _mapController.move(point, _mapZoom);
    } catch (_) {}

    if (label == null) {
      _reverseGeocode(point);
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isGeocoding = true);
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=14&addressdetails=1',
      );
      final request = await client.getUrl(url).timeout(const Duration(seconds: 2));
      request.headers.set('User-Agent', 'NutriGuard-App/1.0 (com.example.nutriguard)');
      final response = await request.close().timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final address = data['address'] as Map<String, dynamic>?;
        final displayName = data['display_name'] as String?;

        String friendlyName = '';
        if (address != null) {
          final road = address['road'] ?? address['suburb'] ?? address['neighbourhood'];
          final city = address['city'] ?? address['town'] ?? address['municipality'] ?? address['county'];
          final state = address['state'];
          if (road != null && city != null) {
            friendlyName = '$road, $city';
          } else if (city != null && state != null) {
            friendlyName = '$city — $state';
          } else if (city != null) {
            friendlyName = '$city';
          }
        }

        if (friendlyName.isEmpty && displayName != null) {
          final parts = displayName.split(',');
          friendlyName = parts.take(2).join(',').trim();
        }

        if (friendlyName.isNotEmpty && mounted) {
          setState(() {
            _destinoCtrl.text = friendlyName;
          });
        }
      }
      client.close();
    } catch (_) {
      // Falha silenciosa: mantém coordenadas
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _clearDestination() {
    setState(() {
      _destinationLatLng = null;
      _destinoCtrl.clear();
    });
    if (_originLatLng != null) {
      try {
        _mapController.move(_originLatLng!, 12.0);
      } catch (_) {}
    }
  }

  void _recenterMap() {
    final target = _destinationLatLng ?? _originLatLng;
    if (target != null) {
      try {
        _mapController.move(target, _mapZoom);
      } catch (_) {}
    }
  }

  void _zoomIn() {
    setState(() {
      _mapZoom = (_mapZoom + 1).clamp(3.0, 18.0);
    });
    final center = _destinationLatLng ?? _originLatLng ?? const LatLng(-23.5505, -46.6333);
    try {
      _mapController.move(center, _mapZoom);
    } catch (_) {}
  }

  void _zoomOut() {
    setState(() {
      _mapZoom = (_mapZoom - 1).clamp(3.0, 18.0);
    });
    final center = _destinationLatLng ?? _originLatLng ?? const LatLng(-23.5505, -46.6333);
    try {
      _mapController.move(center, _mapZoom);
    } catch (_) {}
  }

  String? get _estimatedDistanceText {
    if (_originLatLng == null || _destinationLatLng == null) return null;
    const distance = Distance();
    final km = distance.as(LengthUnit.Kilometer, _originLatLng!, _destinationLatLng!);
    if (km < 1) {
      final meters = distance.as(LengthUnit.Meter, _originLatLng!, _destinationLatLng!);
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  Future<void> _abrirModalMapaCompleto() async {
    HapticFeedback.lightImpact();
    final LatLng? picked = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FullScreenMapPicker(
        initialOrigin: _originLatLng,
        initialDestination: _destinationLatLng,
      ),
    );

    if (picked != null) {
      _selectDestinationPoint(picked);
    }
  }

  Future<void> _iniciarViagem() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    final destino = _destinoCtrl.text.trim();
    if (destino.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, informe o destino da viagem.', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFC23147),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    if (destino.length < 3) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('O destino deve ter pelo menos 3 caracteres.', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFC23147),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    final user = _supabase.currentUser;
    final operatorId = _perfil?.id ?? user?.id ?? '';
    final deviceId = _dispositivo?.id ?? '';

    setState(() => _isStarting = true);

    try {
      await _tripService.startTrip(
        operatorId: operatorId,
        deviceId: deviceId,
        destination: destino,
        vehiclePlate: _dispositivo?.placaVeiculo,
        vehicleModel: _dispositivo?.modeloVeiculo,
        destinationLatitude: _destinationLatLng?.latitude,
        destinationLongitude: _destinationLatLng?.longitude,
      );

      HapticFeedback.mediumImpact();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Viagem para "$destino" iniciada com sucesso!', style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      // Leva direto para o Dashboard do Veículo com a viagem iniciada
      Navigator.pushReplacementNamed(context, '/dashboard-veiculo');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao iniciar viagem: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFC23147),
        ),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _finalizarViagemExistente() async {
    final user = _supabase.currentUser;
    final operatorId = _perfil?.id ?? user?.id ?? '';
    await _tripService.endTrip(operatorId);
    if (!mounted) return;
    setState(() {
      _activeTrip = null;
      _destinationLatLng = null;
      _destinoCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Viagem anterior finalizada.', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFFC23147),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2E0),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Iniciar Viagem',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFC23147),
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFC23147), size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/dashboard-veiculo');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFFC23147)),
            onPressed: () => CustomEndDrawer.showMenu(context),
          ),
        ],
      ),
      body: WatermarkBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC23147)),
                )
              : ResponsiveContentWrapper(
                  maxWidth: ResponsiveBreakpoints.maxFormWidth + 120,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildOperatorHeader(),
                        const SizedBox(height: 16),
                        if (_activeTrip != null) ...[
                          _buildActiveTripAlert(),
                          const SizedBox(height: 16),
                        ],
                        if (_dispositivo == null) ...[
                          _buildNoDeviceCard(),
                        ] else ...[
                          _buildVehicleCard(),
                          const SizedBox(height: 16),
                          _buildFormCard(),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                          const SizedBox(height: 32),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildOperatorHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFC23147).withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: Color(0xFFC23147), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _perfil?.nome ?? 'Operador',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E569),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'OPERADOR',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _perfil?.email ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTripAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8DB600), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.navigation_rounded, color: Color(0xFF2E7D32), size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Você já possui uma viagem em andamento!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Destino atual: ${_activeTrip!.destination}',
            style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          Text(
            'Em trânsito há: ${_activeTrip!.formattedDuration}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard-veiculo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.dashboard_outlined, color: Colors.white, size: 18),
                  label: const Text('Ir para Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _finalizarViagemExistente,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFC23147)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Finalizar', style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoDeviceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 54, color: Color(0xFFC23147)),
          const SizedBox(height: 12),
          const Text(
            'Nenhum veículo vinculado',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Você não possui nenhum veículo ou dispositivo IoT associado ao seu usuário de operador.\n\nPara iniciar uma viagem e obter as informações de telemetria, solicite ao Administrador para vincular um veículo ao seu cadastro.',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _carregarDados,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC23147),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Atualizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard() {
    final dev = _dispositivo!;
    final placa = (dev.placaVeiculo != null && dev.placaVeiculo!.trim().isNotEmpty)
        ? dev.placaVeiculo!
        : 'Placa não cadastrada';
    final modelo = (dev.modeloVeiculo != null && dev.modeloVeiculo!.trim().isNotEmpty)
        ? dev.modeloVeiculo!
        : (dev.modeloDispositivo ?? 'Veículo');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
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
                  color: const Color(0xFFC8E569),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2E7D32), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placa,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      modelo,
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Color(0xFF2E7D32), size: 8),
                    SizedBox(width: 4),
                    Text(
                      'Pronto',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Limite Térmico', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  const SizedBox(height: 2),
                  Text(
                    '${dev.temperaturaMinima?.toStringAsFixed(1) ?? "--"}°C a ${dev.temperaturaMaxima?.toStringAsFixed(1) ?? "--"}°C',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Umidade Permitida', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  const SizedBox(height: 2),
                  Text(
                    '${dev.umidadeMinima?.toStringAsFixed(0) ?? "--"}% a ${dev.umidadeMaxima?.toStringAsFixed(0) ?? "--"}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.sensors, size: 14, color: Colors.black45),
              const SizedBox(width: 4),
              Text(
                'Sensor IoT: ${dev.nomeDispositivo ?? dev.numeroSerie ?? ""}',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.flag_outlined, color: Color(0xFFC23147), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Dados da Viagem',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC23147),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _abrirModalMapaCompleto,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  backgroundColor: const Color(0xFFC8E569).withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF2E7D32)),
                label: const Text(
                  'Mapa Completo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Para onde você vai? *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _destinoCtrl,
            onChanged: (val) {
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Digite o destino ou toque no mapa',
              hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
              prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFFC23147)),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isGeocoding) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC23147)),
                      ),
                    ),
                  ] else if (_destinoCtrl.text.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.black45),
                      onPressed: _clearDestination,
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.pin_drop_rounded, size: 20, color: Color(0xFFC23147)),
                    tooltip: 'Selecionar no Mapa',
                    onPressed: _abrirModalMapaCompleto,
                  ),
                ],
              ),
              filled: true,
              fillColor: const Color(0xFFFFF2E0).withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC23147), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildPresetChips(),
          const SizedBox(height: 16),
          _buildDestinationMapSection(),
          const SizedBox(height: 18),
          const Text(
            'Carga / Observações adicionais',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _obsCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Ex: Transporte de laticínios refrigerados',
              hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
              prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.black45),
              filled: true,
              fillColor: const Color(0xFFFFF2E0).withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC23147), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChips() {
    final presets = [
      {'name': 'CD Central (SP)', 'pos': const LatLng(-23.5505, -46.6333)},
      {'name': 'Hub Campinas', 'pos': const LatLng(-22.9099, -47.0626)},
      {'name': 'Porto de Santos', 'pos': const LatLng(-23.9618, -46.3322)},
      {'name': 'São José dos Campos', 'pos': const LatLng(-23.2237, -45.9009)},
      {'name': 'Ceasa RJ', 'pos': const LatLng(-22.8361, -43.3486)},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presets.map((p) {
          final isSelected = _destinationLatLng != null &&
              (_destinationLatLng!.latitude - (p['pos'] as LatLng).latitude).abs() < 0.01 &&
              (_destinationLatLng!.longitude - (p['pos'] as LatLng).longitude).abs() < 0.01;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(
                Icons.location_on,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFFC23147),
              ),
              label: Text(
                p['name'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              backgroundColor: isSelected ? const Color(0xFFC23147) : const Color(0xFFFFF2E0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFC23147) : Colors.black12,
                ),
              ),
              onPressed: () {
                _selectDestinationPoint(p['pos'] as LatLng, label: p['name'] as String);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDestinationMapSection() {
    final initialPos = _destinationLatLng ?? _originLatLng ?? const LatLng(-23.5505, -46.6333);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header do mapa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF2E0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const Icon(Icons.alt_route_rounded, size: 18, color: Color(0xFFC23147)),
                const SizedBox(width: 8),
                const Text(
                  'Mapa da Rota',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFC23147)),
                ),
                if (_estimatedDistanceText != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '~$_estimatedDistanceText',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const Spacer(),
                InkWell(
                  onTap: _abrirModalMapaCompleto,
                  child: Row(
                    children: const [
                      Icon(Icons.fullscreen_rounded, size: 16, color: Color(0xFFC23147)),
                      SizedBox(width: 2),
                      Text(
                        'Expandir',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Viewport do FlutterMap
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
            child: SizedBox(
              height: 220,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: initialPos,
                      initialZoom: _mapZoom,
                      onTap: (tapPosition, point) {
                        _selectDestinationPoint(point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.nutriguard',
                      ),
                      if (_originLatLng != null && _destinationLatLng != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [_originLatLng!, _destinationLatLng!],
                              color: const Color(0xFFC23147),
                              strokeWidth: 3.5,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_originLatLng != null)
                            Marker(
                              point: _originLatLng!,
                              width: 60,
                              height: 60,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                    ),
                                    child: const Icon(Icons.local_shipping, color: Colors.white, size: 16),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                                    ),
                                    child: const Text('Origem', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          if (_destinationLatLng != null)
                            Marker(
                              point: _destinationLatLng!,
                              width: 65,
                              height: 65,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC23147),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                                    ),
                                    child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC23147),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                                    ),
                                    child: const Text(
                                      'Destino',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  // Botões de zoom e centralização
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      children: [
                        _buildMapMiniButton(icon: Icons.add, onTap: _zoomIn, tooltip: 'Zoom In'),
                        const SizedBox(height: 4),
                        _buildMapMiniButton(icon: Icons.remove, onTap: _zoomOut, tooltip: 'Zoom Out'),
                        const SizedBox(height: 4),
                        _buildMapMiniButton(
                          icon: Icons.my_location_rounded,
                          onTap: _recenterMap,
                          tooltip: 'Centralizar',
                        ),
                      ],
                    ),
                  ),
                  // Banner inferior com dica / confirmação
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _destinationLatLng != null ? Icons.check_circle : Icons.touch_app_rounded,
                            size: 14,
                            color: _destinationLatLng != null ? const Color(0xFF2E7D32) : const Color(0xFFC23147),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _destinationLatLng != null
                                  ? 'Destino marcado no mapa. Toque para alterar.'
                                  : 'Toque em qualquer ponto do mapa para marcar o destino.',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _destinationLatLng != null ? const Color(0xFF2E7D32) : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_destinationLatLng != null)
                            InkWell(
                              onTap: _clearDestination,
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(Icons.close, size: 14, color: Colors.black45),
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
        ],
      ),
    );
  }

  Widget _buildMapMiniButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFFC23147)),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isStarting ? null : _iniciarViagem,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC23147),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _isStarting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
        label: Text(
          _isStarting ? 'Iniciando...' : 'Iniciar viagem',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Modal expansível com mapa em tela cheia para seleção detalhada de destino
class _FullScreenMapPicker extends StatefulWidget {
  final LatLng? initialOrigin;
  final LatLng? initialDestination;

  const _FullScreenMapPicker({
    this.initialOrigin,
    this.initialDestination,
  });

  @override
  State<_FullScreenMapPicker> createState() => _FullScreenMapPickerState();
}

class _FullScreenMapPickerState extends State<_FullScreenMapPicker> {
  final MapController _modalMapController = MapController();
  LatLng? _selectedPoint;
  String _locationName = '';
  double _zoom = 13.0;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialDestination ?? widget.initialOrigin ?? const LatLng(-23.5505, -46.6333);
  }

  void _onTapMap(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _locationName = 'Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCenter = _selectedPoint ?? widget.initialOrigin ?? const LatLng(-23.5505, -46.6333);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Top Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.pin_drop_rounded, color: Color(0xFFC23147), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Selecione o Destino no Mapa',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black12),
          // Search & Hints
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF8DB600)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Toque em qualquer ponto do mapa para posicionar a bandeira de destino.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          // Map View
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _modalMapController,
                  options: MapOptions(
                    initialCenter: effectiveCenter,
                    initialZoom: _zoom,
                    onTap: (tapPosition, point) => _onTapMap(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.nutriguard',
                    ),
                    if (widget.initialOrigin != null && _selectedPoint != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [widget.initialOrigin!, _selectedPoint!],
                            color: const Color(0xFFC23147),
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (widget.initialOrigin != null)
                          Marker(
                            point: widget.initialOrigin!,
                            width: 60,
                            height: 60,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D32),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 16),
                                ),
                                const Text('Origem', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        if (_selectedPoint != null)
                          Marker(
                            point: _selectedPoint!,
                            width: 70,
                            height: 70,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC23147),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                                  ),
                                  child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC23147),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Destino',
                                    style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Zoom buttons
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoomInModal',
                        backgroundColor: Colors.white,
                        onPressed: () {
                          setState(() => _zoom = (_zoom + 1).clamp(3.0, 18.0));
                          if (_selectedPoint != null) _modalMapController.move(_selectedPoint!, _zoom);
                        },
                        child: const Icon(Icons.add, color: Color(0xFFC23147)),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoomOutModal',
                        backgroundColor: Colors.white,
                        onPressed: () {
                          setState(() => _zoom = (_zoom - 1).clamp(3.0, 18.0));
                          if (_selectedPoint != null) _modalMapController.move(_selectedPoint!, _zoom);
                        },
                        child: const Icon(Icons.remove, color: Color(0xFFC23147)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom confirmation action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black12)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_locationName.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.place, size: 16, color: Color(0xFFC23147)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _locationName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _selectedPoint != null
                          ? () {
                              Navigator.pop(context, _selectedPoint);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC23147),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: const Text(
                        'Confirmar este Destino',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
