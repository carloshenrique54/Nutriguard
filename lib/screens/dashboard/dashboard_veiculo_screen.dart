import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../widgets/watermark_background.dart';

class DashboardVeiculoScreen extends StatefulWidget {
  final DispositivoModel? initialDevice;

  const DashboardVeiculoScreen({
    super.key,
    this.initialDevice,
  });

  @override
  State<DashboardVeiculoScreen> createState() => _DashboardVeiculoScreenState();
}

class _DashboardVeiculoScreenState extends State<DashboardVeiculoScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  String _userRole = '';
  String _currentUserId = '';

  List<DispositivoModel> _accessibleDevices = [];
  DispositivoModel? _selectedDevice;
  MedicaoModel? _latestMedicao;
  List<OcorrenciaModel> _alerts = [];

  bool _hasActiveTrip = false;
  String _activeTripDuration = '0h 0m';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.currentUser;
      if (user == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      _currentUserId = user.id;

      final perfil = await _supabase.getUsuarioPerfil(user.id);
      final role = perfil?.role ?? '';
      _userRole = role;

      // Obter argumento de rota se houver
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      DispositivoModel? argDevice;
      if (routeArg is DispositivoModel) {
        argDevice = routeArg;
      } else if (widget.initialDevice != null) {
        argDevice = widget.initialDevice;
      }

      // 1. Filtrar veículos de acordo com a Matriz de Permissões:
      // ADM: Todos os veículos
      // Gerente: Veículos de suas frotas
      // Operador: Apenas o veículo vinculado a si mesmo
      List<DispositivoModel> devices = [];
      if (role == 'admin') {
        devices = await _supabase.getDispositivos();
      } else if (role == 'gerente') {
        final frotas = await _supabase.getFrotasByGerente(user.id);
        for (var f in frotas) {
          final devs = await _supabase.getDispositivosByFrota(f.id);
          devices.addAll(devs);
        }
      } else {
        // Operador
        devices = await _supabase.getDispositivosByOperador(user.id);
      }

      _accessibleDevices = devices;

      // 2. Determinar o veículo selecionado
      if (argDevice != null && devices.any((d) => d.id == argDevice.id)) {
        _selectedDevice = devices.firstWhere((d) => d.id == argDevice.id);
      } else if (devices.isNotEmpty) {
        _selectedDevice = devices.first;
      } else {
        _selectedDevice = null;
      }

      // 3. Carregar dados de telemetria se tiver veículo selecionado
      if (_selectedDevice != null) {
        await _loadTelemetryForDevice(_selectedDevice!);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Erro no Dashboard Veículo: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTelemetryForDevice(DispositivoModel device) async {
    DateTime agora = DateTime.now();
    DateTime inicio = agora.subtract(const Duration(days: 30));

    final medicoes = await _supabase.getMedicoesFiltro([device.id], inicio, agora);
    final ocorrencias = await _supabase.getOcorrenciasFiltro([device.id], inicio, agora);
    ocorrencias.sort((a, b) => (b.criadoEm ?? agora).compareTo(a.criadoEm ?? agora));

    MedicaoModel? latest;
    bool ativa = false;
    String duracaoStr = '0h 0m';

    if (medicoes.isNotEmpty) {
      medicoes.sort((a, b) => a.registradoEm!.compareTo(b.registradoEm!));
      latest = medicoes.last;
      DateTime first = medicoes.first.registradoEm!;
      ativa = agora.difference(latest.registradoEm!).inHours < 2;
      if (ativa) {
        int duracao = agora.difference(first).inMinutes;
        duracaoStr = '${duracao ~/ 60}h ${duracao % 60}m';
      }
    }

    _latestMedicao = latest;
    _alerts = ocorrencias.take(5).toList();
    _hasActiveTrip = ativa;
    _activeTripDuration = duracaoStr;
  }

  void _onSwitchDevice(DispositivoModel d) async {
    setState(() {
      _selectedDevice = d;
      _isLoading = true;
    });
    await _loadTelemetryForDevice(d);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 2,
        isVehicleContext: true,
        currentDevice: _selectedDevice,
      ),
      body: WatermarkBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFC23147)))
              : _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    // 1. Checar se existem veículos acessíveis
    if (_accessibleDevices.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildDeviceSelector(),
          const SizedBox(height: 16),
          _buildGpsQuickBanner(),
          const SizedBox(height: 16),
          _buildTemperatureCard(),
          const SizedBox(height: 16),
          _buildInfoGrid(),
          const SizedBox(height: 16),
          _buildStatusBanner(),
          const SizedBox(height: 16),
          _buildRecentEvents(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isAdmin = _userRole == 'admin';
    final bool isGerente = _userRole == 'gerente';

    String title;
    String description;

    if (isAdmin) {
      title = 'Nenhum veículo cadastrado';
      description = 'Não há nenhum veículo ou dispositivo IoT cadastrado no sistema.';
    } else if (isGerente) {
      title = 'Nenhum veículo na frota';
      description = 'Nenhum veículo foi associado às frotas sob sua gestão. A configuração depende do Administrador.';
    } else {
      title = 'Nenhum veículo vinculado';
      description = 'Você não possui nenhum veículo atribuído ao seu usuário de operador. A configuração depende do Administrador.';
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car_outlined, size: 72, color: Color(0xFFC23147)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
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
                label: const Text('Cadastrar Dispositivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          'Dashboard — Veículo',
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
    );
  }

  Widget _buildDeviceSelector() {
    final dev = _selectedDevice;
    final String devName = dev?.placaVeiculo ?? dev?.nomeDispositivo ?? 'Veículo';

    // Se tiver mais de um veículo (ADM ou Gerente), permite selecionar
    if (_accessibleDevices.length > 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
          child: DropdownButton<DispositivoModel>(
            value: _selectedDevice,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC23147)),
            items: _accessibleDevices.map((d) {
              return DropdownMenuItem<DispositivoModel>(
                value: d,
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, color: Color(0xFF8DB600), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      d.placaVeiculo ?? d.nomeDispositivo ?? 'Veículo',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    if (d.modeloVeiculo != null) ...[
                      const SizedBox(width: 6),
                      Text('(${d.modeloVeiculo})', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _onSwitchDevice(val);
            },
          ),
        ),
      );
    }

    // Apenas um veículo (ex: Operador)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFC8E569).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Color(0xFF8DB600),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          const Text('Vendo: ', style: TextStyle(color: Colors.black54, fontSize: 13)),
          Text(
            devName,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsQuickBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8E569), width: 1.5),
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
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (_selectedDevice != null) {
              Navigator.pushNamed(context, '/gps', arguments: _selectedDevice);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFC23147), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Localização em tempo real (GPS)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                      ),
                      Text(
                        _selectedDevice != null ? 'Acompanhar ${_selectedDevice!.placaVeiculo ?? _selectedDevice!.nomeDispositivo ?? "veículo"}' : 'Abrir mapa',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC23147),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Abrir GPS', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemperatureCard() {
    final dev = _selectedDevice;
    final med = _latestMedicao;
    final num? tempVal = med?.temperatura;
    final num minTemp = dev?.temperaturaMinima ?? 2.0;
    final num maxTemp = dev?.temperaturaMaxima ?? 8.0;

    bool hasTemp = tempVal != null;
    bool inRange = hasTemp && tempVal >= minTemp && tempVal <= maxTemp;
    String statusText = hasTemp ? (inRange ? 'Dentro do limite' : 'Fora do limite') : 'Sem medição recente';

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 28,
                  child: Icon(Icons.thermostat, color: Color(0xFFC23147), size: 32),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Temperatura', style: TextStyle(color: Colors.black87, fontSize: 15)),
                    Text(
                      hasTemp ? '${tempVal.toStringAsFixed(1)}°C' : '-- °C',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: inRange ? Colors.black87 : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              height: 70,
              alignment: Alignment.center,
              child: const Icon(Icons.show_chart, color: Color(0xFFC23147), size: 54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    final dev = _selectedDevice;
    final med = _latestMedicao;

    String lastTimeStr = 'Sem sinal';
    if (med?.registradoEm != null) {
      final diff = DateTime.now().difference(med!.registradoEm!);
      if (diff.inMinutes < 60) {
        lastTimeStr = '${diff.inMinutes} min atrás';
      } else {
        lastTimeStr = '${diff.inHours}h atrás';
      }
    }

    final String umiStr = med?.umidade != null ? '${med!.umidade}%' : '--';
    final String doorStr = med?.portaAberta == true ? 'Aberta' : (med?.portaAberta == false ? 'Fechada' : '--');
    final String batStr = med?.bateria != null ? '${med!.bateria}%' : '--';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.shield_outlined,
                title: 'Limite definido',
                value: '${dev?.temperaturaMinima ?? 2}°C a ${dev?.temperaturaMaxima ?? 8}°C',
                valueSize: 13,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.access_time,
                title: 'Última atualização',
                value: lastTimeStr,
                valueSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.water_drop_outlined,
                title: 'Nível de umidade',
                value: umiStr,
                subtitle: dev?.umidadeMaxima != null ? 'Limite: ${dev!.umidadeMaxima}%' : 'Sensor ativo',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.door_front_door_outlined,
                title: 'Compartimento',
                value: doorStr,
                subtitle: 'Sensor de porta',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.battery_charging_full,
                title: 'Bateria do IoT',
                value: batStr,
                subtitle: 'Nível de carga',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.timer_outlined,
                title: 'Tempo de rota',
                value: _activeTripDuration,
                subtitle: _hasActiveTrip ? 'Em trânsito' : 'Parado',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    double valueSize = 18,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFC23147).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFC23147), size: 18),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: const Color(0xFFC23147),
              fontSize: valueSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black45)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 20,
            child: Icon(
              _alerts.isEmpty ? Icons.check : Icons.warning_amber_rounded,
              color: _alerts.isEmpty ? Colors.green : Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _alerts.isEmpty ? 'Carga em condições normais' : 'Atenção necessária',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
                Text(
                  _alerts.isEmpty ? 'Nenhum alerta recente para este veículo.' : '${_alerts.length} ocorrência(s) registrada(s).',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
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
              onTap: () => Navigator.pushNamed(context, '/alertas-veiculo'),
              child: const Text('Ver todas >', style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x0D000000), blurRadius: 15, offset: Offset(0, 3)),
            ],
          ),
          child: _alerts.isEmpty
              ? const Center(child: Text('Nenhuma ocorrência registrada', style: TextStyle(color: Colors.black54)))
              : Column(
                  children: _alerts.map((alerta) {
                    final isCritical = alerta.tipo != null && alerta.tipo!.toLowerCase().contains('crítico');
                    final time = alerta.criadoEm != null
                        ? '${alerta.criadoEm!.day}/${alerta.criadoEm!.month} ${alerta.criadoEm!.hour}:${alerta.criadoEm!.minute.toString().padLeft(2, '0')}'
                        : '';
                    return Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isCritical ? const Color(0xFFFEEBEE) : const Color(0xFFFFF8E1),
                              radius: 18,
                              child: Icon(
                                isCritical ? Icons.warning_rounded : Icons.info_outline,
                                color: isCritical ? const Color(0xFFC23147) : Colors.orange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(alerta.tipo ?? 'Alerta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
