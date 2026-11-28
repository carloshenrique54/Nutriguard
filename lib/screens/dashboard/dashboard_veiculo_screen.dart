import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../utils/alerta_formatacao.dart';
import '../../widgets/watermark_background.dart';
import '../../services/admin_context_service.dart';
import '../../services/trip_service.dart';
import '../../services/veiculo_operador_service.dart';
import '../../widgets/dashboard_charts.dart';
import '../../services/tempo_real_service.dart';
import '../../widgets/selo_sinal_sensor.dart';
import '../../widgets/responsive_layout.dart';

class DashboardVeiculoScreen extends StatefulWidget {
  final DispositivoModel? initialDevice;

  const DashboardVeiculoScreen({
    super.key,
    this.initialDevice,
  });

  @override
  State<DashboardVeiculoScreen> createState() => _DashboardVeiculoScreenState();
}

class _DashboardVeiculoScreenState extends State<DashboardVeiculoScreen> with OuveTempoReal {
  // Leitura nova do ESP32, alerta ou viagem deste veículo: atualiza na hora.
  @override
  Iterable<String>? get idsEmTela => _selectedDevice == null ? const [] : [_selectedDevice!.id];

  @override
  void aoMudarNoBanco() => _atualizarSilencioso();

  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  String _userRole = '';

  List<DispositivoModel> _accessibleDevices = [];
  DispositivoModel? _selectedDevice;
  MedicaoModel? _latestMedicao;
  List<OcorrenciaModel> _alerts = [];
  bool _gerenteHasFleets = true;

  bool _hasActiveTrip = false;
  String _activeTripDuration = '0h 0m';

  /// Há leitura do sensor nos últimos 5 minutos (telemetria de fato chegando).
  bool get _telemetriaRecente {
    final r = _latestMedicao?.registradoEm;
    return r != null && DateTime.now().difference(r).inMinutes < 5;
  }
  TripInfo? _currentTripInfo;
  UsuarioModel? _currentPerfil;
  String? _currentUserEmail;
  List<double> _recentTemperatures = [];
  List<double> _recentVibrations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
    _atualizacao = Timer.periodic(const Duration(seconds: 5), (_) => _atualizarSilencioso());
  }

  @override
  void dispose() {
    _atualizacao?.cancel();
    super.dispose();
  }

  Timer? _atualizacao;
  bool _atualizando = false;

  /// Leituras do ESP32 chegam a cada poucos segundos: recarrega o veículo
  /// exibido sem mostrar carregamento.
  Future<void> _atualizarSilencioso() async {
    final device = _selectedDevice;
    if (_atualizando || _isLoading || device == null || !mounted) return;
    _atualizando = true;
    try {
      await _loadTelemetryForDevice(device);
      if (mounted && identical(device, _selectedDevice)) setState(() {});
    } catch (e) {
      debugPrint('Atualização automática do painel do veículo falhou: $e');
    } finally {
      _atualizando = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedDevice == null) {
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      if (routeArg is DispositivoModel) {
        _selectedDevice = routeArg;
      } else if (widget.initialDevice != null) {
        _selectedDevice = widget.initialDevice;
      }
      if (_selectedDevice != null && !AdminContextService().hasDevice) {
        AdminContextService().setDevice(_selectedDevice);
      }
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
      _currentUserEmail = user.email;
      final perfil = await _supabase.getUsuarioPerfil(user.id);
      _currentPerfil = perfil;
      final role = perfil?.role ?? '';
      _userRole = role;

      // Obter argumento de rota se houver
      if (!mounted) return;
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      DispositivoModel? argDevice;
      if (routeArg is DispositivoModel) {
        argDevice = routeArg;
      } else if (widget.initialDevice != null) {
        argDevice = widget.initialDevice;
      } else if (_selectedDevice != null) {
        argDevice = _selectedDevice;
      } else if (role == 'admin' && AdminContextService().selectedDevice != null) {
        argDevice = AdminContextService().selectedDevice;
      }

      // Se ADM tem argDevice com frota, resolve e sincroniza a frota de origem com o AdminContextService
      if (role == 'admin' && argDevice != null) {
        FrotaModel? matchedFrota = AdminContextService().selectedFrota;
        if (argDevice.idFrota != null && (matchedFrota == null || matchedFrota.id != argDevice.idFrota)) {
          try {
            final allFrotas = await _supabase.getFrotas();
            matchedFrota = allFrotas.where((f) => f.id == argDevice!.idFrota).firstOrNull;
          } catch (_) {}
        }
        AdminContextService().setDevice(argDevice, frota: matchedFrota ?? AdminContextService().selectedFrota);
      }

      // 1. Filtrar veículos de acordo com a Matriz de Permissões:
      // ADM: Veículos pertencentes à frota selecionada no contexto
      // Gerente: Veículos de suas frotas
      // Operador: Apenas o veículo vinculado a si mesmo
      List<DispositivoModel> devices = [];
      if (role == 'admin') {
        final frotaId = AdminContextService().selectedFrota?.id ?? argDevice?.idFrota;
        if (frotaId != null) {
          try {
            devices = await _supabase.getDispositivosByFrota(frotaId);
          } catch (_) {}
        }
        if (argDevice != null && !devices.any((d) => d.id == argDevice!.id)) {
          devices.add(argDevice);
        }
      } else if (role == 'gerente') {
        final frotas = await _supabase.getFrotasByGerente(user.id);
        _gerenteHasFleets = frotas.isNotEmpty;
        final devLists = await Future.wait(
          frotas.map((f) => _supabase.getDispositivosByFrota(f.id)),
        );
        devices.addAll(devLists.expand((l) => l));
        if (argDevice != null && !devices.any((d) => d.id == argDevice!.id)) {
          devices.add(argDevice);
        }
      } else {
        // Operador
        final targetOperadorId = (perfil?.id != null && perfil!.id.trim().isNotEmpty) ? perfil.id : user.id;
        devices = await _supabase.getDispositivosByOperador(targetOperadorId);
        if (devices.isEmpty && targetOperadorId != user.id) {
          final fallbackDevs = await _supabase.getDispositivosByOperador(user.id);
          if (fallbackDevs.isNotEmpty) {
            devices = fallbackDevs;
          }
        }
        if (argDevice != null && !devices.any((d) => d.id == argDevice!.id)) {
          devices.add(argDevice);
        }
      }

      _accessibleDevices = devices;

      // 2. Determinar o veículo selecionado
      if (argDevice != null) {
        _selectedDevice = devices.firstWhere((d) => d.id == argDevice!.id, orElse: () => argDevice!);
      } else if (role == 'operador' && devices.isNotEmpty) {
        // Operador: veículo da viagem em andamento > escolha salva > primeiro
        final operadorId = (perfil?.id ?? '').trim().isNotEmpty ? perfil!.id : user.id;
        _selectedDevice = await VeiculoOperadorService().resolver(operadorId, devices) ?? devices.first;
      } else if (devices.isNotEmpty) {
        _selectedDevice = devices.first;
      } else {
        _selectedDevice = null;
      }

      if (role == 'admin' && _selectedDevice != null) {
        AdminContextService().setDevice(_selectedDevice, frota: AdminContextService().selectedFrota);
      }

      // 3. Carregar dados de telemetria se tiver veículo selecionado
      if (_selectedDevice != null) {
        try {
          await _loadTelemetryForDevice(_selectedDevice!);
        } catch (err) {
          debugPrint('Erro ao carregar telemetria do veículo: $err');
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Erro no Dashboard Veículo: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTelemetryForDevice(DispositivoModel device) async {
    final DateTime agora = DateTime.now();
    final DateTime inicio = agora.subtract(const Duration(days: 30));

    final isOperador = _userRole == 'operador';
    final user = _supabase.currentUser;
    final operatorId = _currentPerfil?.id ?? user?.id ?? '';

    // Viagem real (tabela `viagens`): do operador logado ou, para admin e
    // gerente, a do veículo exibido.
    TripInfo? tripInfo;
    if (isOperador) {
      if (operatorId.isNotEmpty) tripInfo = await TripService().getActiveTrip(operatorId);
    } else {
      tripInfo = await TripService().getActiveTripByDevice(device.id);
    }
    _currentTripInfo = tripInfo;

    // Operador sem viagem iniciada não vê as leituras (só durante a viagem).
    if (isOperador && tripInfo == null) {
      _hasActiveTrip = false;
      _activeTripDuration = '0h 0m';
      _latestMedicao = null;
      _recentTemperatures = [];
      _recentVibrations = [];
      _alerts = [];
      return;
    }

    // Só as últimas leituras (o painel se atualiza a cada poucos segundos).
    final telemetryResults = await Future.wait([
      _supabase.getUltimasMedicoes(device.id, limite: 20),
      _supabase.getOcorrenciasFiltro([device.id], inicio, agora),
    ]);
    final medicoes = telemetryResults[0] as List<MedicaoModel>;
    final ocorrencias = telemetryResults[1] as List<OcorrenciaModel>;
    ocorrencias.sort((a, b) => (b.criadoEm ?? DateTime(1970)).compareTo(a.criadoEm ?? DateTime(1970)));

    final MedicaoModel? latest = medicoes.isNotEmpty ? medicoes.last : null;
    final bool ativa = tripInfo != null;
    final String duracaoStr = tripInfo?.formattedDuration ?? '0h 0m';

    List<double> ultimos(Iterable<num?> v) {
      final l = v.whereType<num>().map((e) => e.toDouble()).toList();
      return l.length > 10 ? l.sublist(l.length - 10) : l;
    }

    final recentTemps = ultimos(medicoes.map((m) => m.temperatura));
    final recentVibrations = ultimos(medicoes.map((m) => m.vibracao));

    _latestMedicao = latest;
    _recentTemperatures = recentTemps;
    _recentVibrations = recentVibrations;
    _alerts = ocorrencias.take(5).toList();
    _hasActiveTrip = ativa;
    _activeTripDuration = duracaoStr;
  }

  void _onSwitchDevice(DispositivoModel d) async {
    if (_userRole == 'admin') {
      AdminContextService().setDevice(d, frota: AdminContextService().selectedFrota);
    }
    if (_userRole == 'operador') {
      // A viagem pertence a um veículo: durante a viagem não se troca de veículo
      final viagem = _currentTripInfo;
      if (viagem != null && viagem.deviceId.isNotEmpty && viagem.deviceId != d.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Finalize a viagem atual para trocar de veículo.'),
            backgroundColor: Color(0xFFC23147),
          ),
        );
        return;
      }
      final operadorId = _currentPerfil?.id ?? _supabase.currentUser?.id ?? '';
      if (operadorId.isNotEmpty) {
        await VeiculoOperadorService().salvarEscolha(operadorId, d.id);
      }
      if (!mounted) return;
    }
    setState(() {
      _selectedDevice = d;
      _isLoading = true;
    });
    await _loadTelemetryForDevice(d);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = _accessibleDevices.isEmpty && _selectedDevice == null;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 2,
        isVehicleContext: true,
        currentDevice: _selectedDevice,
        isDisabled: isEmpty,
        hasDevicesOverride: !isEmpty,
        userRoleOverride: _userRole.isNotEmpty ? _userRole : null,
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
    // 1. Checar se é ADM e não há veículo selecionado
    if (_userRole == 'admin' && _selectedDevice == null) {
      return ResponsiveContentWrapper(
        maxWidth: 700,
        child: _buildNoDeviceSelectedAdmin(),
      );
    }

    // 2. Checar se existem veículos acessíveis
    if (_accessibleDevices.isEmpty && _selectedDevice == null) {
      return ResponsiveContentWrapper(
        maxWidth: 700,
        child: _buildEmptyState(),
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
          _buildDeviceSelector(),
          ..._buildSinalSensor(),
          if (_userRole == 'operador') ...[
            const SizedBox(height: 14),
            _buildOperatorTripSection(),
          ],
          const SizedBox(height: 14),
          _buildTemperatureCard(),
          const SizedBox(height: 14),
          _buildSplitCard(),
          const SizedBox(height: 14),
          _buildInfoGrid(),
          const SizedBox(height: 14),
          _buildStatusBanner(),
          const SizedBox(height: 14),
          _buildGpsQuickBanner(),
          const SizedBox(height: 18),
          _buildRecentEvents(),
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
          _buildDeviceSelector(),
          ..._buildSinalSensor(),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coluna Esquerda: Viagem, Temperatura, Limites/Tempo, GPS
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_userRole == 'operador') ...[
                      _buildOperatorTripSection(),
                      const SizedBox(height: 16),
                    ],
                    _buildTemperatureCard(),
                    const SizedBox(height: 16),
                    _buildSplitCard(),
                    const SizedBox(height: 16),
                    _buildGpsQuickBanner(),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Coluna Direita: Métricas complementares, Banner de Alerta, Eventos Recentes
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoGrid(),
                    const SizedBox(height: 16),
                    _buildStatusBanner(),
                    const SizedBox(height: 16),
                    _buildRecentEvents(),
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

  Future<void> _finalizarViagemOperador() async {
    final res = await Navigator.pushNamed(context, '/parar-viagem');
    if (res == true && mounted) {
      _fetchData();
    }
  }

  Widget _buildOperatorTripSection() {
    if (!_hasActiveTrip) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC23147).withValues(alpha: 0.3), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
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
                    color: const Color(0xFFC23147).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.play_circle_outline, color: Color(0xFFC23147), size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Viagem não iniciada',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC23147),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Inicie a rota para monitorar a telemetria',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Para começar a registrar a rota e visualizar a temperatura, umidade e alertas em tempo real deste veículo, inicie uma nova viagem.',
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/iniciar-viagem').then((_) => _fetchData());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC23147),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                label: const Text(
                  'Iniciar Viagem',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final dest = _currentTripInfo?.destination ?? 'Em trânsito';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8DB600), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.navigation_rounded, color: Color(0xFF2E7D32), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Viagem em Andamento',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    Text(
                      'Destino: $dest',
                      style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _finalizarViagemOperador,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFC23147)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.stop_circle_outlined, color: Color(0xFFC23147), size: 16),
                label: const Text(
                  'Parar',
                  style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Tempo de rota: $_activeTripDuration',
                  style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _telemetriaRecente ? 'Telemetria ativa em tempo real' : 'Aguardando telemetria do sensor',
                  style: TextStyle(
                    fontSize: 11,
                    color: _telemetriaRecente ? const Color(0xFF2E7D32) : const Color(0xFFB26A00),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
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
                    if (!isAdmin && !isGerente) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC23147).withValues(alpha: 0.2)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Usuário conectado: ${_currentPerfil?.nome ?? "Operador"}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                            ),
                            if (_currentUserEmail != null && _currentUserEmail!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _currentUserEmail!,
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _fetchData();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFC23147),
                              side: const BorderSide(color: Color(0xFFC23147)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Recarregar'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              await _supabase.signOut();
                              if (mounted) Navigator.pushReplacementNamed(context, '/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC23147),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Trocar de Conta'),
                          ),
                        ],
                      ),
                    ],
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
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildNoDeviceSelectedAdmin() {
    final hasFrota = AdminContextService().hasFrota;
    final frotaNome = AdminContextService().currentFrotaName;

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
                    const Icon(Icons.directions_car_outlined, size: 72, color: Color(0xFFC23147)),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum veículo selecionado',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasFrota
                          ? 'Você está no contexto da frota "$frotaNome". Para acessar a telemetria detalhada, selecione um veículo na lista de veículos da frota.'
                          : 'Nenhuma frota ou veículo foi selecionado. Como administrador, inicie escolhendo uma frota para navegar pelo sistema.',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (hasFrota) {
                          Navigator.pushNamed(context, '/listar-dispositivos', arguments: AdminContextService().selectedFrota);
                        } else {
                          Navigator.pushNamed(context, '/listar-frotas');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC23147),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(hasFrota ? Icons.directions_car : Icons.local_shipping, color: Colors.white),
                      label: Text(
                        hasFrota ? 'Ver veículos da frota' : 'Selecionar frota',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildHeader(BuildContext context) {
    final String roleText = (_userRole == 'admin' || _userRole == 'adm')
        ? 'ADM'
        : (_userRole == 'gerente' ? 'GERENTE' : 'OPERADOR');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC23147),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC23147),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      roleText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (_userRole == 'admin' && AdminContextService().hasFrota)
                GestureDetector(
                  onTap: () {
                    AdminContextService().clearVehicle();
                    Navigator.pushNamed(context, '/dashboard-frota', arguments: AdminContextService().selectedFrota);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back, size: 14, color: Color(0xFFC23147)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Frota: ${AdminContextService().currentFrotaName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFC23147),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () {
              final bool isEmpty = _accessibleDevices.isEmpty && _selectedDevice == null;
              CustomEndDrawer.showMenu(
                context,
                userRoleOverride: _userRole.isNotEmpty ? _userRole : null,
                hasFleetsOverride: _userRole == 'gerente'
                    ? _gerenteHasFleets
                    : (_userRole == 'admin' && AdminContextService().hasFrota ? true : null),
                hasDevicesOverride: !isEmpty,
              );
            },
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
    );
  }

  /// Conexão do ESP32/Wokwi (operador sem viagem não vê leituras, então não vê o selo).
  List<Widget> _buildSinalSensor() {
    if (_selectedDevice == null || (_userRole == 'operador' && !_hasActiveTrip)) return const [];
    return [
      const SizedBox(height: 10),
      SeloSinalSensor(ultimaLeitura: _latestMedicao?.registradoEm),
    ];
  }

  Widget _buildDeviceSelector() {
    final dev = _selectedDevice;
    final String devName = dev?.placaVeiculo ?? dev?.nomeDispositivo ?? 'Veículo';

    if (_accessibleDevices.length <= 1) {
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
            Flexible(
              child: Text(
                devName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<DispositivoModel>(
      onSelected: _onSwitchDevice,
      itemBuilder: (ctx) => _accessibleDevices.map((d) {
        return PopupMenuItem<DispositivoModel>(
          value: d,
          child: Row(
            children: [
              const Icon(Icons.directions_car, color: Color(0xFF8DB600), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d.placaVeiculo ?? d.nomeDispositivo ?? 'Veículo',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (d.modeloVeiculo != null) ...[
                const SizedBox(width: 4),
                Text('(${d.modeloVeiculo})', style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
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
            Flexible(
              child: Text(
                devName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Color(0xFFC23147), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsQuickBanner() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8E569), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFC23147), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Localização em tempo real (GPS)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                      ),
                      Text(
                        _selectedDevice != null ? 'Acompanhar ${_selectedDevice!.placaVeiculo ?? _selectedDevice!.nomeDispositivo ?? "veículo"}' : 'Abrir mapa',
                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC23147),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Abrir GPS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
    String statusText = hasTemp ? (inRange ? 'Dentro do limite' : 'Fora do limite') : 'Sem leituras';
    if (!hasTemp) inRange = true;

    if (_userRole == 'operador' && !_hasActiveTrip) {
      hasTemp = false;
      statusText = 'Viagem não iniciada';
      inRange = true;
    }

    final String tempDisplay = hasTemp && tempVal != null
        ? '${tempVal.toStringAsFixed(1).replaceAll('.', ',')}°C'
        : '--';

    // Sem leituras o gráfico fica vazio (nada de valores de exemplo).
    final List<double> chartPoints = hasTemp ? _recentTemperatures : const <double>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 28,
            child: Icon(Icons.thermostat, color: Color(0xFFC23147), size: 36),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Temperatura',
                  style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tempDisplay,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: inRange ? Colors.black87 : const Color(0xFFC23147),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 120,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: CustomPaint(
              size: const Size(120, 80),
              painter: TemperatureMiniChartPainter(
                currentTemp: tempVal?.toDouble(),
                points: chartPoints,
                minLimit: minTemp.toDouble(),
                maxLimit: maxTemp.toDouble(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitCard() {
    final dev = _selectedDevice;
    final med = _latestMedicao;

    String lastTimeStr = 'Sem leituras';
    if (_userRole == 'operador' && !_hasActiveTrip) {
      lastTimeStr = 'Não iniciada';
    } else if (med?.registradoEm != null) {
      final diff = DateTime.now().difference(med!.registradoEm!);
      if (diff.inMinutes < 60) {
        lastTimeStr = '${diff.inMinutes <= 0 ? 1 : diff.inMinutes} minuto(s) atrás';
      } else if (diff.inHours < 24) {
        lastTimeStr = '${diff.inHours}h atrás';
      } else {
        lastTimeStr = '${diff.inDays} dia(s) atrás';
      }
    }

    final String limitStr = (dev?.temperaturaMinima != null && dev?.temperaturaMaxima != null)
        ? '${AlertaFormatacao.numero(dev!.temperaturaMinima!)} a ${AlertaFormatacao.numero(dev.temperaturaMaxima!)}°C'
        : (dev?.temperaturaMaxima != null ? '${AlertaFormatacao.numero(dev!.temperaturaMaxima!)}°C' : '--');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC23147),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Limite definido',
                        style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        limitStr,
                        style: const TextStyle(
                          color: Color(0xFFC23147),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: Colors.black12,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC23147),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.access_time, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Última atualização',
                        style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lastTimeStr,
                        style: const TextStyle(
                          color: Color(0xFFC23147),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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

  Widget _buildInfoGrid() {
    final dev = _selectedDevice;
    final med = _latestMedicao;

    // Operador sem viagem iniciada não vê leituras; sem medição mostra "--".
    final bool oculto = _userRole == 'operador' && !_hasActiveTrip;
    final MedicaoModel? m = oculto ? null : med;

    final num? umidade = m?.umidade;
    final String umiStr = umidade != null ? '${AlertaFormatacao.numero(umidade)}%' : '--';
    final num? umiMax = dev?.umidadeMaxima;
    final num? umiMin = dev?.umidadeMinima;
    final bool umiForaLimite = umidade != null &&
        ((umiMax != null && umidade > umiMax) || (umiMin != null && umidade < umiMin));
    final String umiStatus = oculto
        ? 'Não iniciada'
        : (umidade == null ? 'Sem leituras' : (umiForaLimite ? 'Fora do limite' : 'Dentro do limite'));

    final bool semPorta = m?.portaAberta == null;
    final bool isDoorClosed = m?.portaAberta != true;
    final String doorStatus = oculto ? 'Não iniciada' : (semPorta ? 'Sem leituras' : (isDoorClosed ? 'Fechado' : 'Aberto'));

    final String batStr = m?.bateria != null ? '${AlertaFormatacao.numero(m!.bateria!)}%' : '--';

    final num? vibVal = m?.vibracao;
    final double currentVib = vibVal?.toDouble() ?? 0.0;

    final double limiteVib = (dev?.limiteVibracao ?? 6).toDouble();
    final bool isVibAlert = vibVal != null && currentVib > limiteVib;

    final String vibStr = vibVal != null ? '${AlertaFormatacao.numero(currentVib)} m/s²' : '--';

    final String vibStatusText = oculto
        ? 'Não iniciada'
        : (vibVal == null ? 'Sem leituras' : (isVibAlert ? 'Alerta' : 'Estável'));

    return Column(
      children: [
        // Linha 1: Umidade + Vibração
        Row(
          children: [
            // Card 1: Nível de umidade
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                height: 145,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC23147),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.water_drop_outlined, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Nivel de umidade',
                            style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      umiStr,
                      style: const TextStyle(
                        color: Color(0xFFC23147),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: umiForaLimite ? const Color(0xFFFFCDD2) : const Color(0xFFC8E569),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            umiStatus,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: umiForaLimite ? const Color(0xFFC23147) : const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Limite definido:', style: TextStyle(fontSize: 8, color: Colors.black54)),
                            Text(
                              umiMax != null ? '${AlertaFormatacao.numero(umiMax)}%' : '--',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Card 2: Nível de vibração
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                height: 145,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC23147),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.vibration, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Nivel de vibração',
                            style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          vibStr,
                          style: TextStyle(
                            color: isVibAlert ? const Color(0xFFC23147) : const Color(0xFF0D9488),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVibAlert
                                ? const Color(0xFFFFCDD2)
                                : const Color(0xFFC8E569),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            vibStatusText,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isVibAlert ? const Color(0xFFC23147) : const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: CustomPaint(
                          painter: VibrationMiniChartPainter(
                            values: oculto ? const <double>[] : _recentVibrations,
                            limit: limiteVib,
                            currentVibration: currentVib,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Limite definido: ${AlertaFormatacao.numero(limiteVib)} m/s²',
                      style: const TextStyle(fontSize: 8, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Linha 2: Compartimento + Bateria
        Row(
          children: [
            // Card 3: Compartimento
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC23147),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sensor_door_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Compartimento',
                            style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDoorClosed ? const Color(0xFFC8E569) : const Color(0xFFFFCDD2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              doorStatus,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDoorClosed ? const Color(0xFF2E7D32) : const Color(0xFFC23147),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Card 4: Bateria
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC23147),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.battery_charging_full_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Bateria',
                            style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            batStr,
                            style: const TextStyle(
                              color: Color(0xFFC23147),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    // Só alertas de sensor ainda abertos pedem atenção (avisos de viagem e
    // alertas resolvidos não).
    final abertos = _alerts
        .where((a) => !AlertaFormatacao.resolvido(a.status) && !AlertaFormatacao.informativo(a.tipo))
        .length;
    final hasAlerts = abertos > 0;
    final semLeituras = _latestMedicao == null;
    final title = hasAlerts
        ? 'Atenção necessária'
        : (semLeituras ? 'Aguardando dados do sensor' : 'Carga em condições normais');
    final subtitle = hasAlerts
        ? '$abertos ocorrência(s) em aberto'
        : (semLeituras
            ? 'Nenhuma leitura recebida deste veículo ainda'
            : 'Todos os parâmetros estão dentro dos limites');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasAlerts
                  ? Icons.warning_amber_rounded
                  : (semLeituras ? Icons.sensors_off_outlined : Icons.check_circle_outline_rounded),
              color: hasAlerts ? const Color(0xFFC23147) : const Color(0xFF8DB600),
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const DeliveryTruckGraphic(width: 90, height: 44),
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
              'Eventos recentes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/alertas-veiculo'),
              child: const Row(
                children: [
                  Text(
                    'Ver todos',
                    style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 16, color: Color(0xFFC23147)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: _alerts.isNotEmpty
                ? _alerts.take(3).map((alerta) {
                    final isCritical = AlertaFormatacao.critico(alerta.tipo);
                    final time = alerta.criadoEm != null
                        ? '${alerta.criadoEm!.hour.toString().padLeft(2, '0')}:${alerta.criadoEm!.minute.toString().padLeft(2, '0')}'
                        : '';
                    return Column(
                      children: [
                        _buildEventItem(
                          icon: AlertaFormatacao.iconeViagem(alerta.tipo) ??
                              (isCritical ? Icons.warning_amber_rounded : Icons.thermostat),
                          title: AlertaFormatacao.titulo(alerta.tipo),
                          detail1Label: '',
                          detail1Val: AlertaFormatacao.detalhe(alerta),
                          time: time,
                        ),
                        if (alerta != _alerts.take(3).last) const Divider(height: 18, color: Colors.black12),
                      ],
                    );
                  }).toList()
                : [_eventoSemAlertas()],
          ),
        ),
      ],
    );
  }

  /// Sem alertas: mostra a última leitura real, ou que ainda não há eventos.
  Widget _eventoSemAlertas() {
    final m = (_userRole == 'operador' && !_hasActiveTrip) ? null : _latestMedicao;
    if (m == null) {
      return _buildEventItem(
        icon: Icons.inbox_outlined,
        title: 'Nenhum evento registrado',
        detail1Label: 'Os eventos aparecem quando o sensor envia dados',
        detail1Val: '',
        time: '',
      );
    }
    return _buildEventItem(
      icon: Icons.thermostat,
      title: 'Condições normais',
      detail1Label: m.temperatura != null ? 'Temperatura: ' : null,
      detail1Val: m.temperatura != null ? '${AlertaFormatacao.numero(m.temperatura!)}°C' : null,
      detail2Label: m.umidade != null ? 'Umidade: ' : null,
      detail2Val: m.umidade != null ? '${AlertaFormatacao.numero(m.umidade!)}%' : null,
      time: AlertaFormatacao.dataHora(m.registradoEm).split(' ').last,
    );
  }

  Widget _buildEventItem({
    required IconData icon,
    required String title,
    String? detail1Label,
    String? detail1Val,
    String? detail2Label,
    String? detail2Val,
    required String time,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFC8E569),
          child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (detail1Label != null && detail1Val != null) ...[
                    Text(detail1Label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    Text(
                      detail1Val,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                    ),
                  ],
                  if (detail2Label != null && detail2Val != null) ...[
                    Container(
                      width: 1,
                      height: 10,
                      color: Colors.black26,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    Text(detail2Label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    Text(
                      detail2Val,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            const Icon(Icons.access_time, size: 14, color: Color(0xFFC23147)),
            const SizedBox(width: 4),
            Text(
              time,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
            ),
          ],
        ),
      ],
    );
  }
}
