import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../widgets/watermark_background.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../services/admin_context_service.dart';
import '../../services/trip_service.dart';

class ViagemData {
  final DispositivoModel dispositivo;
  final FrotaModel? frota;
  final DateTime inicio;
  final DateTime? fim;
  final bool ativa;
  final int duracaoMinutos;
  final int qtdeAlertas;

  ViagemData({
    required this.dispositivo,
    this.frota,
    required this.inicio,
    this.fim,
    required this.ativa,
    required this.duracaoMinutos,
    required this.qtdeAlertas,
  });
}

class RelatoriosScreen extends StatefulWidget {
  final bool isVehicleContext;
  final String? userRole;
  final SupabaseService? supabaseService;

  const RelatoriosScreen({
    super.key,
    this.isVehicleContext = false,
    this.userRole,
    this.supabaseService,
  });

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  late final SupabaseService _supabase = widget.supabaseService ?? SupabaseService();
  
  UsuarioModel? _perfil;
  List<FrotaModel> _frotas = [];
  List<DispositivoModel> _dispositivos = [];
  
  String _periodoSelecionado = 'Dia'; // Dia, Semana, Mês
  String? _selectedFrotaId;
  String? _selectedDispositivoId;
  String _selectedTelemetriaParametro = 'Temperatura';
  bool _isBarChart = true;

  bool _isLoading = true;
  String _errorMessage = '';

  List<MedicaoModel> _medicoes = [];
  List<OcorrenciaModel> _ocorrencias = [];
  final List<ViagemData> _viagens = [];

  int _totalViagens = 0;
  int _tempoRotaAtual = 0;
  int _tempoMedioViagem = 0;
  double _conformidade = 0;
  int _alertasRecebidos = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final user = _supabase.currentUser;
      if (user != null) {
        _perfil = await _supabase.getUsuarioPerfil(user.id);
        if (_perfil != null) {
          final role = _perfil!.role;

          // Operador não tem permissão para Relatórios de Frota
          if (!widget.isVehicleContext && role == 'operador') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Acesso negado para seu perfil. Redirecionando para Veículo.', style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.pushReplacementNamed(context, '/relatorios-veiculo');
            }
            return;
          }

          if (role == 'admin') {
            _frotas = await _supabase.getFrotas();
            if (widget.isVehicleContext && AdminContextService().selectedFrota != null) {
              _dispositivos = await _supabase.getDispositivosByFrota(AdminContextService().selectedFrota!.id);
            } else {
              _dispositivos = await _supabase.getDispositivos();
            }
          } else if (role == 'gerente') {
            _frotas = await _supabase.getFrotasByGerente(_perfil!.id);
            List<DispositivoModel> allDevices = [];
            for (var frota in _frotas) {
              final devs = await _supabase.getDispositivosByFrota(frota.id);
              allDevices.addAll(devs);
            }
            _dispositivos = allDevices;
          } else {
            // Operador
            _frotas = await _supabase.getFrotasByOperador(_perfil!.id);
            _dispositivos = await _supabase.getDispositivosByOperador(_perfil!.id);
          }

          // Checar se veio veículo ou frota por argumento de rota
          if (!mounted) return;
          final routeArg = ModalRoute.of(context)?.settings.arguments;
          DispositivoModel? targetDevice = routeArg is DispositivoModel ? routeArg : null;
          FrotaModel? targetFrota = routeArg is FrotaModel ? routeArg : null;

          if (role == 'admin') {
            if (widget.isVehicleContext && targetDevice == null && AdminContextService().selectedDevice != null) {
              targetDevice = AdminContextService().selectedDevice;
            } else if (!widget.isVehicleContext && targetFrota == null && AdminContextService().selectedFrota != null) {
              targetFrota = AdminContextService().selectedFrota;
            }
          }

          if (widget.isVehicleContext) {
            if (targetDevice != null && _dispositivos.any((d) => d.id == targetDevice!.id)) {
              _selectedDispositivoId = targetDevice.id;
            } else if (targetDevice != null) {
              _selectedDispositivoId = targetDevice.id;
            } else if (role != 'admin' && _dispositivos.isNotEmpty) {
              _selectedDispositivoId = _dispositivos.first.id;
            } else {
              _selectedDispositivoId = null;
            }
            if (role == 'admin' && _selectedDispositivoId != null) {
              final d = _dispositivos.where((x) => x.id == _selectedDispositivoId).firstOrNull ?? targetDevice;
              if (d != null) AdminContextService().setDevice(d, frota: AdminContextService().selectedFrota);
            }
          } else {
            if (targetFrota != null && _frotas.any((f) => f.id == targetFrota!.id)) {
              _selectedFrotaId = targetFrota.id;
            } else if (targetFrota != null) {
              _selectedFrotaId = targetFrota.id;
            } else if (role != 'admin' && _frotas.isNotEmpty) {
              _selectedFrotaId = _frotas.first.id;
            } else {
              _selectedFrotaId = null;
            }
            if (role == 'admin' && _selectedFrotaId != null) {
              final f = _frotas.where((x) => x.id == _selectedFrotaId).firstOrNull ?? targetFrota;
              if (f != null) AdminContextService().setFrota(f);
            }
          }
          
          await _loadReportData();
        }
      } else {
        setState(() { _errorMessage = 'Usuário não autenticado'; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Erro ao carregar dados iniciais: $e'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadReportData() async {
    if (_perfil == null) return;
    setState(() { _isLoading = true; });
    try {
      DateTime agora = DateTime.now();
      DateTime inicio;
      DateTime fim = agora;

      if (_periodoSelecionado == 'Dia') {
        inicio = DateTime(agora.year, agora.month, agora.day);
      } else if (_periodoSelecionado == 'Semana') {
        inicio = agora.subtract(Duration(days: agora.weekday - 1));
        inicio = DateTime(inicio.year, inicio.month, inicio.day);
      } else {
        inicio = DateTime(agora.year, agora.month, 1);
      }

      List<DispositivoModel> targetDevices = _dispositivos;
      if (_selectedFrotaId != null && _selectedFrotaId!.isNotEmpty) {
        targetDevices = targetDevices.where((d) => d.idFrota == _selectedFrotaId).toList();
      }
      if (_selectedDispositivoId != null && _selectedDispositivoId!.isNotEmpty) {
        targetDevices = targetDevices.where((d) => d.id == _selectedDispositivoId).toList();
      }

      List<String> deviceIds = targetDevices.map((d) => d.id).toList();

      _medicoes = await _supabase.getMedicoesFiltro(deviceIds, inicio, fim);
      _ocorrencias = await _supabase.getOcorrenciasFiltro(deviceIds, inicio, fim);

      await _calculateMetrics(targetDevices);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar relatórios: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _calculateMetrics(List<DispositivoModel> devices) async {
    _viagens.clear();
    _tempoRotaAtual = 0;
    _tempoMedioViagem = 0;
    _alertasRecebidos = _ocorrencias.length;

    int totalValidas = 0;
    int dentroLimite = 0;
    
    // Configura limites padroes
    const num minTempDefault = 2.0;
    const num maxTempDefault = 8.0;

    for (var d in devices) {
      var meds = _medicoes.where((m) => m.idDispositivo == d.id).toList();
      if (meds.isNotEmpty) {
        meds.sort((a, b) => a.registradoEm!.compareTo(b.registradoEm!));
        
        DateTime inicio = meds.first.registradoEm!;
        DateTime fim = meds.last.registradoEm!;
        
        // Verifica se o dispositivo está com uma viagem realmente ativa no TripService
        bool ativa = await TripService().isDeviceInTrip(d.id, operatorId: d.idOperador);
        int duracao = fim.difference(inicio).inMinutes;

        if (ativa && duracao > _tempoRotaAtual) {
          _tempoRotaAtual = duracao;
        }

        int qtdeAl = _ocorrencias.where((o) => o.idDispositivo == d.id).length;
        
        FrotaModel? f = _frotas.where((f) => f.id == d.idFrota).firstOrNull;
        
        _viagens.add(ViagemData(
          dispositivo: d,
          frota: f,
          inicio: inicio,
          fim: ativa ? null : fim,
          ativa: ativa,
          duracaoMinutos: duracao,
          qtdeAlertas: qtdeAl,
        ));

        num tMin = d.temperaturaMinima ?? minTempDefault;
        num tMax = d.temperaturaMaxima ?? maxTempDefault;

        for (var m in meds) {
          if (m.temperatura != null) {
            totalValidas++;
            if (m.temperatura! >= tMin && m.temperatura! <= tMax) {
              dentroLimite++;
            }
          }
        }
      }
    }

    _totalViagens = _viagens.length;
    _conformidade = totalValidas > 0 ? (dentroLimite / totalValidas) * 100 : 100.0;
    
    if (_viagens.isEmpty) {
      _conformidade = 0.0;
      _tempoMedioViagem = 0;
    } else {
      int totalDuracao = 0;
      for (var v in _viagens) {
        totalDuracao += v.duracaoMinutos;
      }
      _tempoMedioViagem = totalDuracao ~/ _viagens.length;
    }
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();

    // Pre-calcula estatísticas de telemetria para o PDF
    MedicaoModel? latestMed;
    double? avgTemp;
    double? minTemp;
    double? maxTemp;
    double? avgUmid;
    double? maxVib;

    if (_medicoes.isNotEmpty) {
      final sortedMeds = List<MedicaoModel>.from(_medicoes)
        ..sort((a, b) => (a.registradoEm ?? DateTime(2000)).compareTo(b.registradoEm ?? DateTime(2000)));
      latestMed = sortedMeds.last;

      final temps = sortedMeds.where((m) => m.temperatura != null).map((m) => m.temperatura!.toDouble()).toList();
      if (temps.isNotEmpty) {
        avgTemp = temps.reduce((a, b) => a + b) / temps.length;
        minTemp = temps.reduce((a, b) => a < b ? a : b);
        maxTemp = temps.reduce((a, b) => a > b ? a : b);
      }

      final umids = sortedMeds.where((m) => m.umidade != null).map((m) => m.umidade!.toDouble()).toList();
      if (umids.isNotEmpty) {
        avgUmid = umids.reduce((a, b) => a + b) / umids.length;
      }

      final vibs = sortedMeds.where((m) => m.vibracao != null).map((m) => m.vibracao!.toDouble()).toList();
      if (vibs.isNotEmpty) {
        maxVib = vibs.reduce((a, b) => a > b ? a : b);
      }
    }

    final sortedOcorrencias = List<OcorrenciaModel>.from(_ocorrencias)
      ..sort((a, b) => (b.criadoEm ?? DateTime(2000)).compareTo(a.criadoEm ?? DateTime(2000)));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NutriGuard - Relatório', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                  pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
                ]
              )
            ),
            pw.SizedBox(height: 16),
            pw.Text('Filtros Aplicados:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Período: $_periodoSelecionado', style: const pw.TextStyle(fontSize: 11)),
            if (_selectedFrotaId != null && _selectedFrotaId!.isNotEmpty)
               pw.Text('Frota ID: $_selectedFrotaId', style: const pw.TextStyle(fontSize: 11)),
            if (_selectedDispositivoId != null && _selectedDispositivoId!.isNotEmpty)
               pw.Text('Dispositivo ID: $_selectedDispositivoId', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),
            pw.Text('Resumo dos Indicadores:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: 'Viagens no período: $_totalViagens'),
            pw.Bullet(
              text: widget.isVehicleContext
                  ? (_tempoRotaAtual > 0
                      ? 'Tempo na rota atual: ${_tempoRotaAtual ~/ 60}h ${_tempoRotaAtual % 60}m'
                      : 'Tempo médio de viagem: ${_tempoMedioViagem ~/ 60}h ${_tempoMedioViagem % 60}m')
                  : 'Tempo médio de viagem: ${_tempoMedioViagem ~/ 60}h ${_tempoMedioViagem % 60}m',
            ),
            pw.Bullet(text: 'Conformidade: ${_conformidade.toStringAsFixed(1)}%'),
            pw.Bullet(text: 'Alertas Recebidos: $_alertasRecebidos'),
            pw.SizedBox(height: 16),
            pw.Text(
              _selectedDispositivoId == null ? 'Telemetria Consolidada da Frota:' : 'Telemetria e Condições Ambientais:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            if (_selectedDispositivoId == null) ...[
              pw.Bullet(text: 'Temperatura Média da Frota: ${avgTemp != null ? "${avgTemp.toStringAsFixed(1)}°C" : "N/D"} | Mín: ${minTemp?.toStringAsFixed(1) ?? "N/D"}°C | Máx: ${maxTemp?.toStringAsFixed(1) ?? "N/D"}°C'),
              pw.Bullet(text: 'Umidade Média da Frota: ${avgUmid != null ? "${avgUmid.toStringAsFixed(0)}%" : "N/D"}'),
              pw.Bullet(text: 'Pico Máximo de Vibração na Frota: ${maxVib != null ? "${maxVib.toStringAsFixed(2)}G" : "N/D"}'),
              pw.Bullet(text: 'Menor Bateria da Frota: ${latestMed?.bateria != null ? "${latestMed!.bateria!.toStringAsFixed(0)}%" : "N/D"} | Porta: ${latestMed?.portaAberta == true ? "Aberta" : "Fechada"}'),
            ] else ...[
              pw.Bullet(text: 'Temperatura: ${latestMed?.temperatura != null ? "${latestMed!.temperatura!.toStringAsFixed(1)}°C (última)" : "N/D"} | Média: ${avgTemp?.toStringAsFixed(1) ?? "N/D"}°C | Mín: ${minTemp?.toStringAsFixed(1) ?? "N/D"}°C | Máx: ${maxTemp?.toStringAsFixed(1) ?? "N/D"}°C'),
              pw.Bullet(text: 'Umidade: ${latestMed?.umidade != null ? "${latestMed!.umidade!.toStringAsFixed(0)}% (última)" : "N/D"} | Média: ${avgUmid?.toStringAsFixed(0) ?? "N/D"}%'),
              pw.Bullet(text: 'Vibração: ${latestMed?.vibracao != null ? "${latestMed!.vibracao!.toStringAsFixed(2)}G (última)" : "N/D"} | Pico máx: ${maxVib?.toStringAsFixed(2) ?? "N/D"}G'),
              pw.Bullet(text: 'Bateria e Compartimento: ${latestMed?.bateria != null ? "${latestMed!.bateria!.toStringAsFixed(0)}%" : "N/D"} | Porta: ${latestMed?.portaAberta == true ? "Aberta" : "Fechada"}'),
            ],
            pw.SizedBox(height: 16),
            pw.Text('Alertas e Ocorrências Recentes (${_ocorrencias.length}):', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            if (sortedOcorrencias.isEmpty)
              pw.Text('Nenhum alerta registrado neste período.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey, fontSize: 11))
            else
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Data/Hora', 'Dispositivo / Placa', 'Tipo', 'Registrado', 'Limite', 'Status'],
                data: sortedOcorrencias.take(20).map((o) {
                  final dev = _dispositivos.where((d) => d.id == o.idDispositivo).firstOrNull;
                  return [
                    o.criadoEm != null ? DateFormat('dd/MM/yy HH:mm').format(o.criadoEm!) : '-',
                    dev?.placaVeiculo ?? dev?.nomeDispositivo ?? o.idDispositivo ?? 'N/D',
                    o.tipo ?? 'Alerta',
                    o.valorRegistrado?.toString() ?? '-',
                    o.limiteConfigurado?.toString() ?? '-',
                    o.status ?? 'Pendente',
                  ];
                }).toList(),
              ),
            pw.SizedBox(height: 16),
            pw.Text('Lista de Viagens (${_viagens.length}):', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            if (_viagens.isEmpty)
              pw.Text('Nenhuma viagem realizada neste período.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey, fontSize: 11))
            else
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Dispositivo', 'Placa', 'Início', 'Fim', 'Duração', 'Status', 'Alertas'],
                data: _viagens.map((v) => [
                  v.dispositivo.nomeDispositivo ?? 'N/D',
                  v.dispositivo.placaVeiculo ?? 'N/D',
                  DateFormat('dd/MM/yy HH:mm').format(v.inicio),
                  v.fim != null ? DateFormat('dd/MM/yy HH:mm').format(v.fim!) : '-',
                  '${v.duracaoMinutos ~/ 60}h ${v.duracaoMinutos % 60}m',
                  v.ativa ? 'Em andamento' : 'Finalizada',
                  v.qtdeAlertas.toString(),
                ]).toList(),
              ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'NutriGuard_Relatorio.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 1,
        isVehicleContext: widget.isVehicleContext,
        currentDevice: widget.isVehicleContext
            ? _dispositivos.where((d) => d.id == _selectedDispositivoId).firstOrNull
            : null,
      ),
      body: WatermarkBackground(
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFC23147)))
            : (!widget.isVehicleContext && _frotas.isEmpty)
                ? _buildNoContextSelectedState('frota', noRegisteredEntities: true)
                : (widget.isVehicleContext && _dispositivos.isEmpty)
                    ? _buildNoContextSelectedState('veículo', noRegisteredEntities: true)
                    : (_perfil?.role == 'admin' && !widget.isVehicleContext && _selectedFrotaId == null)
                        ? _buildNoContextSelectedState('frota', noRegisteredEntities: false)
                        : (_perfil?.role == 'admin' && widget.isVehicleContext && _selectedDispositivoId == null)
                            ? _buildNoContextSelectedState('veículo', noRegisteredEntities: false)
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHeader(context),
                                    const SizedBox(height: 16),
                                    if (_errorMessage.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                                      ),
                                    _buildFiltrosExtras(),
                                    const SizedBox(height: 16),
                                    _buildPeriodToggle(),
                                    const SizedBox(height: 20),
                                    if (_medicoes.isEmpty && _ocorrencias.isEmpty && _viagens.isEmpty)
                                      _buildEmptyPeriodBanner(),
                                    _buildMetricsGrid(),
                                    const SizedBox(height: 20),
                                    _buildRecentTelemetryCards(),
                                    const SizedBox(height: 24),
                                    _buildChart1(),
                                    const SizedBox(height: 24),
                                    _buildChart2(),
                                    const SizedBox(height: 24),
                                    _buildRecentAlertsSection(),
                                    const SizedBox(height: 24),
                                    _buildViagens(),
                                    const SizedBox(height: 24),
                                    _buildExportButton(),
                                    const SizedBox(height: 80),
                                  ],
                                ),
                              ),
        ),
      ),
    );
  }

  Widget _buildEmptyPeriodBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC23147).withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFC23147).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline_rounded, color: Color(0xFFC23147), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nenhum dado registrado no período ($_periodoSelecionado)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Não foram encontradas medições ou viagens para o filtro de $_periodoSelecionado. Experimente alternar para outro período no seletor acima para auditar datas anteriores.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoContextSelectedState(String tipo, {bool noRegisteredEntities = false}) {
    final bool isFrota = tipo == 'frota';
    final role = _perfil?.role ?? '';

    String title;
    String description;
    String badgeLabel;
    IconData iconData;
    Widget? actionButton;

    if (noRegisteredEntities) {
      if (role == 'gerente') {
        badgeLabel = 'NENHUMA FROTA ATRIBUÍDA';
        title = 'Você não possui frotas atribuídas';
        description = 'Para gerar e visualizar relatórios operacionais, uma frota deve ser vinculada à sua gestão pelo Administrador.';
        iconData = Icons.shield_outlined;
        actionButton = OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            _loadInitialData();
          },
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC23147)),
          label: const Text('Atualizar dados', style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFC23147), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        );
      } else if (role == 'operador') {
        badgeLabel = 'NENHUM VEÍCULO ATRIBUÍDO';
        title = 'Nenhum veículo vinculado ao seu perfil';
        description = 'Você ainda não possui veículos sob sua operação. Solicite ao seu Gerente ou Administrador o vínculo de um veículo.';
        iconData = Icons.directions_car_outlined;
        actionButton = OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            _loadInitialData();
          },
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC23147)),
          label: const Text('Atualizar dados', style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFC23147), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        );
      } else {
        // Admin with 0 fleets or 0 devices in database
        badgeLabel = isFrota ? 'SEM FROTAS CADASTRADAS' : 'SEM VEÍCULOS CADASTRADOS';
        title = isFrota ? 'Nenhuma frota cadastrada no sistema' : 'Nenhum veículo cadastrado no sistema';
        description = isFrota 
            ? 'Cadastre uma frota para começar a monitorar a conformidade, temperaturas e viagens dos veículos.'
            : 'Cadastre veículos e dispositivos para visualizar telemetria e relatórios em tempo real.';
        iconData = isFrota ? Icons.local_shipping_outlined : Icons.sensors_outlined;
        actionButton = ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            if (isFrota) {
              Navigator.pushNamed(context, '/cadastrar-frota');
            } else {
              Navigator.pushNamed(context, '/cadastrar-dispositivo');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC23147),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            isFrota ? 'Criar Primeira Frota' : 'Cadastrar Veículo',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        );
      }
    } else {
      // Normal context selection required (Admin hasn't selected yet)
      badgeLabel = 'SELEÇÃO NECESSÁRIA';
      title = isFrota ? 'Nenhuma frota selecionada' : 'Nenhum veículo selecionado';
      description = isFrota
          ? 'Para visualizar os indicadores consolidados, conformidade e registros térmicos, selecione uma frota ativa.'
          : 'Para consultar medições em tempo real, trajetos e ocorrências, selecione um veículo.';
      iconData = isFrota ? Icons.local_shipping_outlined : Icons.directions_car_outlined;
      actionButton = ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          if (isFrota) {
            Navigator.pushNamed(context, '/listar-frotas');
          } else if (AdminContextService().hasFrota) {
            Navigator.pushNamed(context, '/listar-dispositivos', arguments: AdminContextService().selectedFrota);
          } else {
            Navigator.pushNamed(context, '/listar-frotas');
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC23147),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        icon: Icon(isFrota ? Icons.local_shipping : Icons.directions_car, color: Colors.white),
        label: Text(
          isFrota ? 'Selecionar Frota' : (AdminContextService().hasFrota ? 'Ver Veículos da Frota' : 'Selecionar Frota'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Multi-layer stylized icon badge
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFC23147).withValues(alpha: 0.08),
                  ),
                  child: Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFC23147), Color(0xFF8E1B2C)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC23147).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(iconData, size: 36, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Pill Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC23147).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      color: Color(0xFFC23147),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E1E),
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Description
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Preview feature card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2E0).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC23147).withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      _buildPreviewFeatureRow(Icons.show_chart_rounded, 'Gráficos de temperatura e histórico térmico'),
                      const SizedBox(height: 10),
                      _buildPreviewFeatureRow(Icons.verified_outlined, 'Índices de conformidade e controle de rota'),
                      const SizedBox(height: 10),
                      _buildPreviewFeatureRow(Icons.picture_as_pdf_outlined, 'Exportação de relatórios auditáveis em PDF'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                actionButton,
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPreviewFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
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
          child: Icon(icon, size: 16, color: const Color(0xFFC23147)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF444444),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final role = _perfil?.role ?? '';
    final isOperador = role == 'operador';
    final String roleBadge = (role == 'admin' || role == 'adm')
        ? 'ADM'
        : (role == 'gerente' ? 'GERENTE' : 'Operador');
    final String titleText = isOperador
        ? 'Relatório'
        : (widget.isVehicleContext ? 'Relatório — Veículo' : 'Relatório — Frota');

    return Row(
      children: [
        if (Navigator.canPop(context)) ...[
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(Icons.arrow_back, color: Color(0xFFC23147), size: 26),
            ),
          ),
        ],
        Text(
          titleText,
          style: const TextStyle(
            color: Color(0xFFC23147),
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_perfil != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFC23147),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              roleBadge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: () => CustomEndDrawer.showMenu(
            context,
            userRoleOverride: _perfil?.role,
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
      ],
    );
  }

  Widget _buildFiltrosExtras() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.isVehicleContext && _frotas.isNotEmpty) ...[
          const Text('Frota', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC23147))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _frotas.any((f) => f.id == _selectedFrotaId) ? _selectedFrotaId : null,
                isExpanded: true,
                hint: const Text('Selecione uma frota'),
                items: _frotas.map((f) => DropdownMenuItem(value: f.id, child: Text(f.nome ?? 'Sem nome'))).toList(),
                onChanged: (val) {
                  final newId = val;
                  if (_perfil?.role == 'admin' && newId != null) {
                    final f = _frotas.where((x) => x.id == newId).firstOrNull;
                    if (f != null) AdminContextService().setFrota(f);
                  }
                  setState(() {
                    _selectedFrotaId = newId;
                    _selectedDispositivoId = null; 
                  });
                  _loadReportData();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.isVehicleContext && _dispositivos.isNotEmpty) ...[
          const Text('Veículo', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC23147))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _dispositivos.any((d) => d.id == _selectedDispositivoId) ? _selectedDispositivoId : null,
                isExpanded: true,
                hint: const Text('Selecione um veículo'),
                items: _dispositivos.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nomeDispositivo ?? d.placaVeiculo ?? d.id.substring(0,8)))).toList(),
                onChanged: (val) {
                  final newId = val;
                  if (_perfil?.role == 'admin' && newId != null) {
                    final d = _dispositivos.where((x) => x.id == newId).firstOrNull;
                    if (d != null) AdminContextService().setDevice(d, frota: AdminContextService().selectedFrota);
                  }
                  setState(() {
                    _selectedDispositivoId = newId;
                  });
                  _loadReportData();
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: ['Dia', 'Semana', 'Mês'].map((period) {
          bool isSelected = _periodoSelecionado == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() { _periodoSelecionado = period; });
                _loadReportData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFC23147) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF555555),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final bool showRotaAtual = widget.isVehicleContext && _tempoRotaAtual > 0;
    final int tempoMinutos = showRotaAtual ? _tempoRotaAtual : _tempoMedioViagem;

    String tempoStr;
    if (tempoMinutos == 0) {
      tempoStr = '0h 0m';
    } else {
      final h = tempoMinutos ~/ 60;
      final m = tempoMinutos % 60;
      tempoStr = m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
    }

    final String tempoTitle = showRotaAtual ? 'Tempo na rota atual' : 'Tempo médio de viagem';

    String conformidadeStr;
    if (_conformidade == 0.0) {
      conformidadeStr = '0.0%';
    } else if (_conformidade == _conformidade.roundToDouble()) {
      conformidadeStr = '${_conformidade.toInt()}%';
    } else {
      conformidadeStr = '${_conformidade.toStringAsFixed(0)}%';
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      childAspectRatio: 2.3,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricCard(
          title: 'Viagens no período',
          value: '$_totalViagens',
          icon: Icons.map_outlined,
        ),
        _buildMetricCard(
          title: tempoTitle,
          value: tempoStr,
          icon: showRotaAtual ? Icons.access_time_rounded : Icons.timer_outlined,
        ),
        _buildMetricCard(
          title: 'Conformidade',
          value: conformidadeStr,
          icon: Icons.check_box_rounded,
        ),
        _buildMetricCard(
          title: 'Alertas recebidos',
          value: '$_alertasRecebidos',
          icon: Icons.warning_amber_rounded,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFC23147),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFC23147),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTelemetryCards() {
    final bool isFleet = _selectedDispositivoId == null;
    MedicaoModel? latestMed;
    double? avgTemp;
    double? minTemp;
    double? maxTemp;
    double? avgUmid;
    double? maxVib;

    if (_medicoes.isNotEmpty) {
      final sortedMeds = List<MedicaoModel>.from(_medicoes)
        ..sort((a, b) => (a.registradoEm ?? DateTime(2000)).compareTo(b.registradoEm ?? DateTime(2000)));
      latestMed = sortedMeds.last;

      final temps = sortedMeds.where((m) => m.temperatura != null).map((m) => m.temperatura!.toDouble()).toList();
      if (temps.isNotEmpty) {
        avgTemp = temps.reduce((a, b) => a + b) / temps.length;
        minTemp = temps.reduce((a, b) => a < b ? a : b);
        maxTemp = temps.reduce((a, b) => a > b ? a : b);
      }

      final umids = sortedMeds.where((m) => m.umidade != null).map((m) => m.umidade!.toDouble()).toList();
      if (umids.isNotEmpty) {
        avgUmid = umids.reduce((a, b) => a + b) / umids.length;
      }

      final vibs = sortedMeds.where((m) => m.vibracao != null).map((m) => m.vibracao!.toDouble()).toList();
      if (vibs.isNotEmpty) {
        maxVib = vibs.reduce((a, b) => a > b ? a : b);
      }
    }

    // Identifica última medição por dispositivo para análises detalhadas da frota
    final Map<String, MedicaoModel> latestByDevice = {};
    for (final m in _medicoes) {
      if (m.idDispositivo != null) {
        final existing = latestByDevice[m.idDispositivo!];
        if (existing == null || (m.registradoEm ?? DateTime(2000)).isAfter(existing.registradoEm ?? DateTime(2000))) {
          latestByDevice[m.idDispositivo!] = m;
        }
      }
    }

    // Busca o veículo com a menor bateria e contabiliza status das portas na frota
    MedicaoModel? minBatMed;
    DispositivoModel? minBatDev;
    int openDoorsCount = 0;
    int totalDoorsReported = 0;

    for (final entry in latestByDevice.entries) {
      final m = entry.value;
      if (m.bateria != null) {
        if (minBatMed == null || m.bateria! < minBatMed.bateria!) {
          minBatMed = m;
          minBatDev = _dispositivos.where((d) => d.id == entry.key).firstOrNull;
        }
      }
      if (m.portaAberta != null) {
        totalDoorsReported++;
        if (m.portaAberta == true) {
          openDoorsCount++;
        }
      }
    }

    // Fallback caso não haja agrupamento por dispositivo
    if (minBatMed == null && latestMed?.bateria != null) {
      minBatMed = latestMed;
      minBatDev = _dispositivos.where((d) => d.id == latestMed?.idDispositivo).firstOrNull;
    }

    // Parâmetros dos cards adaptados para Frota vs Veículo Específico
    final String tempTitle = isFleet ? 'Temperatura Média' : 'Temperatura';
    final String tempStr = isFleet
        ? (avgTemp != null ? '${avgTemp.toStringAsFixed(1)}°C' : (latestMed?.temperatura != null ? '${latestMed!.temperatura!.toStringAsFixed(1)}°C' : '--'))
        : (latestMed?.temperatura != null ? '${latestMed!.temperatura!.toStringAsFixed(1)}°C' : '--');
    final String tempSub = isFleet
        ? (minTemp != null && maxTemp != null ? 'Mín ${minTemp.toStringAsFixed(0)}° / Máx ${maxTemp.toStringAsFixed(0)}° (Frota)' : 'Média consolidada')
        : (avgTemp != null ? 'Méd: ${avgTemp.toStringAsFixed(1)}° (Mín ${minTemp!.toStringAsFixed(0)}° / Máx ${maxTemp!.toStringAsFixed(0)}°)' : 'Sem dados');

    final String umidTitle = isFleet ? 'Umidade Média' : 'Umidade';
    final String umidStr = isFleet
        ? (avgUmid != null ? '${avgUmid.toStringAsFixed(0)}%' : (latestMed?.umidade != null ? '${latestMed!.umidade!.toStringAsFixed(0)}%' : '--'))
        : (latestMed?.umidade != null ? '${latestMed!.umidade!.toStringAsFixed(0)}%' : '--');
    final String umidSub = isFleet ? 'Consolidado da frota' : (avgUmid != null ? 'Média no período: ${avgUmid.toStringAsFixed(0)}%' : 'Sem dados');

    final String vibTitle = isFleet ? 'Pico de Vibração' : 'Vibração';
    final String vibStr = isFleet
        ? (maxVib != null ? '${maxVib.toStringAsFixed(2)}G' : (latestMed?.vibracao != null ? '${latestMed!.vibracao!.toStringAsFixed(2)}G' : '--'))
        : (latestMed?.vibracao != null ? '${latestMed!.vibracao!.toStringAsFixed(2)}G' : '--');
    final String vibSub = isFleet ? 'Maior impacto na frota' : (maxVib != null ? 'Pico máx: ${maxVib.toStringAsFixed(2)}G' : 'Estável');

    final String batTitle = isFleet ? 'Menor Bateria' : 'Bateria & Porta';
    final String batStr = isFleet
        ? (minBatMed?.bateria != null ? '${minBatMed!.bateria!.toStringAsFixed(0)}%' : (latestMed?.bateria != null ? '${latestMed!.bateria!.toStringAsFixed(0)}%' : '--'))
        : (latestMed?.bateria != null ? '${latestMed!.bateria!.toStringAsFixed(0)}%' : '--');

    final String portaInfoFleet = openDoorsCount > 0
        ? '$openDoorsCount porta(s) aberta(s)'
        : (totalDoorsReported > 0 ? 'Portas fechadas' : '');

    final String batSub = isFleet
        ? (minBatMed != null
            ? '${minBatDev?.placaVeiculo ?? minBatDev?.nomeDispositivo ?? "Veículo"}${portaInfoFleet.isNotEmpty ? " • $portaInfoFleet" : ""}'
            : 'Sem dados')
        : (latestMed != null ? (latestMed.portaAberta == true ? 'Porta aberta' : 'Porta fechada') : 'Sem dados');

    final IconData batIcon = isFleet
        ? Icons.battery_alert_rounded
        : Icons.battery_charging_full_rounded;

    final Color batColor = isFleet
        ? (minBatMed?.bateria != null && minBatMed!.bateria! < 25
            ? const Color(0xFFC23147)
            : (minBatMed?.bateria != null && minBatMed!.bateria! < 50
                ? const Color(0xFFE65100)
                : const Color(0xFF2E7D32)))
        : const Color(0xFF2E7D32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isFleet ? 'Telemetria Recente da Frota' : 'Telemetria Recente',
              style: const TextStyle(color: Color(0xFF222222), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (latestMed?.registradoEm != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF777777)),
                    const SizedBox(width: 4),
                    Text(
                      'Última: ${DateFormat('dd/MM HH:mm').format(latestMed!.registradoEm!)}',
                      style: const TextStyle(color: Color(0xFF666666), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          childAspectRatio: 2.1,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildTelemetryCard(
              title: tempTitle,
              value: tempStr,
              subtitle: tempSub,
              icon: Icons.thermostat_rounded,
              color: const Color(0xFFC23147),
            ),
            _buildTelemetryCard(
              title: umidTitle,
              value: umidStr,
              subtitle: umidSub,
              icon: Icons.water_drop_outlined,
              color: const Color(0xFF0288D1),
            ),
            _buildTelemetryCard(
              title: vibTitle,
              value: vibStr,
              subtitle: vibSub,
              icon: Icons.vibration_rounded,
              color: const Color(0xFFE65100),
            ),
            _buildTelemetryCard(
              title: batTitle,
              value: batStr,
              subtitle: batSub,
              icon: batIcon,
              color: batColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTelemetryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChartState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    String? badgeText,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          if (badgeText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1E1E1E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF757575),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart1() {
    double limit = 8.0;
    String limitLabel = '8°C';
    String paramTitle = 'Temperatura média';

    if (_selectedTelemetriaParametro == 'Umidade') {
      limit = 60.0;
      limitLabel = '60%';
      paramTitle = 'Umidade média';
    } else if (_selectedTelemetriaParametro == 'Vibração') {
      limit = 2.0;
      limitLabel = '2.0G';
      paramTitle = 'Vibração média';
    } else {
      // Temperatura
      if (_dispositivos.isNotEmpty && _selectedDispositivoId != null) {
        final d = _dispositivos.where((x) => x.id == _selectedDispositivoId).firstOrNull;
        if (d?.temperaturaMaxima != null) {
          limit = d!.temperaturaMaxima!.toDouble();
          limitLabel = '${limit.toStringAsFixed(0)}°C';
        }
      }
    }

    if (_medicoes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTelemetryHeader(paramTitle),
          const SizedBox(height: 12),
          Container(
            height: 195,
            padding: const EdgeInsets.all(16),
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
            child: _buildEmptyChartState(
              icon: Icons.show_chart_rounded,
              title: 'Sem medições de temperatura',
              subtitle: 'Nenhum registro térmico capturado no período ($_periodoSelecionado).',
              color: const Color(0xFFC23147),
              badgeText: 'SEM MEDIÇÕES',
            ),
          ),
        ],
      );
    }

    final sorted = List<MedicaoModel>.from(_medicoes);
    sorted.sort((a, b) => a.registradoEm!.compareTo(b.registradoEm!));
    DateTime t0 = sorted.first.registradoEm!;
    DateTime tEnd = sorted.last.registradoEm!;
    if (tEnd.difference(t0).inMinutes < 60) {
      tEnd = t0.add(const Duration(hours: 1));
    }
    final int totalMin = tEnd.difference(t0).inMinutes;

    const int numSlots = 7;
    final double slotWidthMin = totalMin / (numSlots - 1);

    List<String> timeLabels = [];
    List<FlSpot> spots = [];
    List<BarChartGroupData> barGroups = [];
    bool hasAnyAlert = false;
    double maxYFound = limit;
    double minYFound = limit;

    for (int i = 0; i < numSlots; i++) {
      DateTime slotCenter = t0.add(Duration(minutes: (slotWidthMin * i).round()));
      DateTime windowStart = slotCenter.subtract(Duration(minutes: (slotWidthMin / 2).round()));
      DateTime windowEnd = slotCenter.add(Duration(minutes: (slotWidthMin / 2).round()));

      timeLabels.add(DateFormat('H:mm').format(slotCenter));

      List<double> slotVals = [];
      for (var m in sorted) {
        final reg = m.registradoEm!;
        if (!reg.isBefore(windowStart) && !reg.isAfter(windowEnd)) {
          double? v;
          if (_selectedTelemetriaParametro == 'Umidade') {
            v = m.umidade?.toDouble();
          } else if (_selectedTelemetriaParametro == 'Vibração') {
            v = m.vibracao?.toDouble();
          } else {
            v = m.temperatura?.toDouble();
          }
          if (v != null) slotVals.add(v);
        }
      }

      double avgY;
      if (slotVals.isNotEmpty) {
        avgY = slotVals.reduce((a, b) => a + b) / slotVals.length;
      } else {
        double? nearestVal;
        int minDiff = 99999999;
        for (var m in sorted) {
          int diff = (m.registradoEm!.difference(slotCenter).inMinutes).abs();
          if (diff < minDiff) {
            minDiff = diff;
            if (_selectedTelemetriaParametro == 'Umidade') {
              nearestVal = m.umidade?.toDouble();
            } else if (_selectedTelemetriaParametro == 'Vibração') {
              nearestVal = m.vibracao?.toDouble();
            } else {
              nearestVal = m.temperatura?.toDouble();
            }
          }
        }
        avgY = nearestVal ?? (limit * 0.6);
      }

      final roundedY = double.parse(avgY.toStringAsFixed(1));
      if (roundedY > maxYFound) maxYFound = roundedY;
      if (roundedY < minYFound) minYFound = roundedY;
      if (roundedY > limit) hasAnyAlert = true;

      spots.add(FlSpot(i.toDouble(), roundedY));
    }

    double minY = 0.0;
    double maxY = 12.0;
    double yInterval = 4.0;
    String unitSuffix = '°';

    if (_selectedTelemetriaParametro == 'Umidade') {
      minY = 0.0;
      maxY = 100.0;
      yInterval = 25.0;
      unitSuffix = '%';
    } else if (_selectedTelemetriaParametro == 'Vibração') {
      minY = 0.0;
      maxY = (maxYFound > 2.0 ? maxYFound + 0.8 : 3.0).ceilToDouble();
      yInterval = 1.0;
      unitSuffix = 'G';
    } else {
      // Temperatura
      minY = 0.0;
      maxY = (maxYFound > limit ? maxYFound + 3.0 : limit + 4.0).ceilToDouble();
      if (maxY < 12.0) maxY = 12.0;
      yInterval = (maxY / 3).roundToDouble();
      if (yInterval < 2) yInterval = 2;
      unitSuffix = '°';
    }

    for (int i = 0; i < spots.length; i++) {
      final y = spots[i].y;
      final bool isOverLimit = y > limit;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: y,
              color: isOverLimit ? const Color(0xFFC23147) : const Color(0xFF8DB600),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: Colors.black.withValues(alpha: 0.04),
              ),
            ),
          ],
        ),
      );
    }

    final double avgFound = spots.isNotEmpty
        ? (spots.map((s) => s.y).reduce((a, b) => a + b) / spots.length)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTelemetryHeader(paramTitle),
        const SizedBox(height: 12),
        Container(
          height: 225,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC23147),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Limite: $limitLabel',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF555555),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Média: ${avgFound.toStringAsFixed(1)}$unitSuffix',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF777777),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasAnyAlert
                          ? const Color(0xFFFDE8EC)
                          : const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: hasAnyAlert
                            ? const Color(0xFFF8BBD0)
                            : const Color(0xFFD4E7B5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasAnyAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          size: 11,
                          color: hasAnyAlert ? const Color(0xFFC23147) : const Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          hasAnyAlert ? 'Alerta registrado' : 'Dentro do limite',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: hasAnyAlert ? const Color(0xFFC23147) : const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _isBarChart
                    ? BarChart(
                        BarChartData(
                          minY: minY,
                          maxY: maxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: yInterval,
                            getDrawingHorizontalLine: (val) => FlLine(
                              color: Colors.black.withValues(alpha: 0.05),
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: limit,
                                color: const Color(0xFFC23147).withValues(alpha: 0.6),
                                strokeWidth: 1.2,
                                dashArray: [4, 4],
                              ),
                            ],
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: yInterval,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()}$unitSuffix',
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF888888)),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) {
                                  int idx = value.round();
                                  if (idx >= 0 && idx < timeLabels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        timeLabels[idx],
                                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF777777)),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          barGroups: barGroups,
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: 6,
                          minY: minY,
                          maxY: maxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: yInterval,
                            getDrawingHorizontalLine: (val) => FlLine(
                              color: Colors.black.withValues(alpha: 0.05),
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: limit,
                                color: const Color(0xFFC23147).withValues(alpha: 0.6),
                                strokeWidth: 1.2,
                                dashArray: [4, 4],
                              ),
                            ],
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: yInterval,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()}$unitSuffix',
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF888888)),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  int idx = value.round();
                                  if (idx >= 0 && idx < timeLabels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        timeLabels[idx],
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          color: Color(0xFF777777),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: false,
                              color: const Color(0xFF8DB600),
                              barWidth: 2.4,
                              isStrokeCapRound: true,
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF8DB600).withValues(alpha: 0.22),
                                    const Color(0xFF8DB600).withValues(alpha: 0.01),
                                  ],
                                ),
                              ),
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  final isOver = spot.y > limit;
                                  return FlDotCirclePainter(
                                    radius: isOver ? 4.5 : 3.0,
                                    color: isOver ? const Color(0xFFC23147) : const Color(0xFF8DB600),
                                    strokeWidth: 1.5,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF222222),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        // Toggle Linha / Barras
        Container(
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 5,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => setState(() => _isBarChart = false),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: !_isBarChart ? const Color(0xFFC23147).withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                  ),
                  child: Icon(
                    Icons.show_chart_rounded,
                    size: 17,
                    color: !_isBarChart ? const Color(0xFFC23147) : Colors.black45,
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _isBarChart = true),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isBarChart ? const Color(0xFFC23147).withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    size: 17,
                    color: _isBarChart ? const Color(0xFFC23147) : Colors.black45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTelemetriaParametro,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54, size: 18),
              style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
              items: ['Temperatura', 'Umidade', 'Vibração'].map((String p) {
                return DropdownMenuItem<String>(value: p, child: Text(p));
              }).toList(),
              onChanged: (newVal) {
                if (newVal != null) {
                  setState(() => _selectedTelemetriaParametro = newVal);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChart2() {
    if (_ocorrencias.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alertas',
            style: TextStyle(color: Color(0xFF222222), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            height: 180,
            padding: const EdgeInsets.all(16),
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
            child: _buildEmptyChartState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Nenhum alerta registrado',
              subtitle: 'Todos os parâmetros operaram em conformidade no período ($_periodoSelecionado).',
              color: const Color(0xFF8DB600),
              badgeText: 'CONFORME',
            ),
          ),
        ],
      );
    }

    DateTime t0;
    DateTime tEnd;
    if (_medicoes.isNotEmpty) {
      final sortedM = List<MedicaoModel>.from(_medicoes);
      sortedM.sort((a, b) => a.registradoEm!.compareTo(b.registradoEm!));
      t0 = sortedM.first.registradoEm!;
      tEnd = sortedM.last.registradoEm!;
    } else {
      final sortedO = List<OcorrenciaModel>.from(_ocorrencias);
      sortedO.sort((a, b) => a.criadoEm!.compareTo(b.criadoEm!));
      t0 = sortedO.first.criadoEm!;
      tEnd = sortedO.last.criadoEm!;
    }

    if (tEnd.difference(t0).inMinutes < 60) {
      tEnd = t0.add(const Duration(hours: 1));
    }
    final int totalMin = tEnd.difference(t0).inMinutes;

    List<String> timeLabels = [];
    for (int i = 0; i < 7; i++) {
      DateTime slotTime = t0.add(Duration(minutes: (totalMin * (i / 6)).round()));
      if (i == 0) {
        timeLabels.add('${DateFormat('H:mm').format(slotTime)}\n(Início)');
      } else if (i == 6) {
        timeLabels.add('${DateFormat('H:mm').format(slotTime)}\n(Agora)');
      } else {
        timeLabels.add(DateFormat('H:mm').format(slotTime));
      }
    }

    List<int> countsPerSlot = List.filled(7, 0);
    for (var o in _ocorrencias) {
      if (o.criadoEm != null) {
        int mMin = o.criadoEm!.difference(t0).inMinutes;
        int slot = ((mMin / totalMin) * 6.0).clamp(0.0, 6.0).round();
        countsPerSlot[slot]++;
      }
    }

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < 7; i++) {
      int count = countsPerSlot[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: const Color(0xFFC23147),
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alertas',
          style: TextStyle(color: Color(0xFF222222), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          height: 180,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
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
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: 4,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: const Color(0xFFE57373).withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      int idx = value.round();
                      if (idx >= 0 && idx < timeLabels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            timeLabels[idx],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF777777),
                              height: 1.1,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              barGroups: barGroups,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentAlertsSection() {
    final sortedOcorrencias = List<OcorrenciaModel>.from(_ocorrencias)
      ..sort((a, b) => (b.criadoEm ?? DateTime(2000)).compareTo(a.criadoEm ?? DateTime(2000)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Alertas & Ocorrências',
                  style: TextStyle(color: Color(0xFF222222), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _ocorrencias.isNotEmpty
                        ? const Color(0xFFC23147).withValues(alpha: 0.12)
                        : const Color(0xFF8DB600).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_ocorrencias.length}',
                    style: TextStyle(
                      color: _ocorrencias.isNotEmpty ? const Color(0xFFC23147) : const Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            if (sortedOcorrencias.isNotEmpty)
              Text(
                'Últimos ${sortedOcorrencias.length > 5 ? 5 : sortedOcorrencias.length} eventos',
                style: const TextStyle(fontSize: 11, color: Color(0xFF777777), fontWeight: FontWeight.w500),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (sortedOcorrencias.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF8DB600).withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8DB600).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D32), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nenhuma ocorrência registrada',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF222222)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Nenhuma anomalia de temperatura, vibração ou umidade detectada no período.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF666666), height: 1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...sortedOcorrencias.take(5).map((o) => _buildAlertCard(o)),
      ],
    );
  }

  Widget _buildAlertCard(OcorrenciaModel o) {
    final dev = _dispositivos.where((d) => d.id == o.idDispositivo).firstOrNull;
    final String nomeVeiculo = dev?.placaVeiculo ?? dev?.nomeDispositivo ?? (o.idDispositivo != null ? 'Dispositivo ${o.idDispositivo!.substring(0, o.idDispositivo!.length > 8 ? 8 : o.idDispositivo!.length)}' : 'Veículo');
    final String tipoLower = (o.tipo ?? '').toLowerCase();

    IconData alertIcon = Icons.warning_amber_rounded;
    Color alertColor = const Color(0xFFC23147);
    String unit = '';

    if (tipoLower.contains('vibr')) {
      alertIcon = Icons.vibration_rounded;
      alertColor = const Color(0xFFE65100);
      unit = 'G';
    } else if (tipoLower.contains('umid')) {
      alertIcon = Icons.water_drop_outlined;
      alertColor = const Color(0xFF0288D1);
      unit = '%';
    } else if (tipoLower.contains('porta')) {
      alertIcon = Icons.sensor_door_outlined;
      alertColor = const Color(0xFFE65100);
    } else {
      alertIcon = Icons.thermostat_rounded;
      alertColor = const Color(0xFFC23147);
      unit = '°C';
    }

    final bool isResolvido = (o.status ?? '').toLowerCase() == 'resolvido';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alertColor.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(alertIcon, color: alertColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        o.tipo ?? 'Alerta de Telemetria',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: alertColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isResolvido
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFDE8EC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isResolvido ? 'Resolvido' : (o.status ?? 'Pendente'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isResolvido
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC23147),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      nomeVeiculo,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    if (o.valorRegistrado != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• Registrado: ${o.valorRegistrado}$unit',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
                      ),
                    ],
                    if (o.limiteConfigurado != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(Limite: ${o.limiteConfigurado}$unit)',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF888888)),
                      ),
                    ],
                  ],
                ),
                if (o.criadoEm != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 11, color: Color(0xFF999999)),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(o.criadoEm!),
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViagens() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Viagens',
          style: TextStyle(color: Color(0xFF222222), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_viagens.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text(
                'Nenhuma viagem realizada',
                style: TextStyle(
                  color: Color(0xFF757575),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          )
        else
          ..._viagens.map((v) => _buildViagemCard(v)),
      ],
    );
  }

  Widget _buildViagemCard(ViagemData v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                v.dispositivo.placaVeiculo ?? v.dispositivo.nomeDispositivo ?? 'Veículo',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: v.ativa ? const Color(0xFFE8F5E9) : const Color(0xFFFEEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  v.ativa ? 'Em andamento' : 'Finalizada',
                  style: TextStyle(
                    color: v.ativa ? Colors.green[800] : Colors.red[800],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                'Duração: ${v.duracaoMinutos ~/ 60}h ${v.duracaoMinutos % 60}m',
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                'Alertas: ${v.qtdeAlertas}',
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                'Início: ${DateFormat('dd/MM HH:mm').format(v.inicio)}',
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _exportToPDF,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC23147),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Exportar PDF',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
