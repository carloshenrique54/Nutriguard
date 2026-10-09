import 'package:flutter/material.dart';
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

  const RelatoriosScreen({
    super.key,
    this.isVehicleContext = false,
    this.userRole,
  });

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  final SupabaseService _supabase = SupabaseService();
  
  UsuarioModel? _perfil;
  List<FrotaModel> _frotas = [];
  List<DispositivoModel> _dispositivos = [];
  
  String _periodoSelecionado = 'Dia'; // Dia, Semana, Mês
  String? _selectedFrotaId;
  String? _selectedDispositivoId;

  bool _isLoading = true;
  String _errorMessage = '';

  List<MedicaoModel> _medicoes = [];
  List<OcorrenciaModel> _ocorrencias = [];
  final List<ViagemData> _viagens = [];

  int _totalViagens = 0;
  int _tempoRotaAtual = 0;
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
            _dispositivos = await _supabase.getDispositivos();
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

          // Checar se veio veículo por argumento de rota
          final routeArg = ModalRoute.of(context)?.settings.arguments;
          if (routeArg is DispositivoModel) {
            _selectedDispositivoId = routeArg.id;
          } else if (widget.isVehicleContext && _dispositivos.isNotEmpty) {
            _selectedDispositivoId ??= _dispositivos.first.id;
          }

          if (!widget.isVehicleContext && _frotas.isNotEmpty) {
            _selectedFrotaId ??= _frotas.first.id;
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

      _calculateMetrics(targetDevices);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar relatórios: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _calculateMetrics(List<DispositivoModel> devices) {
    _viagens.clear();
    _tempoRotaAtual = 0;
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
        bool ativa = DateTime.now().difference(fim).inHours < 2;
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
    
    if (_viagens.isEmpty) _conformidade = 0.0;
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();

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
            pw.SizedBox(height: 20),
            pw.Text('Filtros Aplicados:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Período: $_periodoSelecionado', style: const pw.TextStyle(fontSize: 12)),
            if (_selectedFrotaId != null && _selectedFrotaId!.isNotEmpty)
               pw.Text('Frota ID: $_selectedFrotaId', style: const pw.TextStyle(fontSize: 12)),
            if (_selectedDispositivoId != null && _selectedDispositivoId!.isNotEmpty)
               pw.Text('Dispositivo ID: $_selectedDispositivoId', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),
            pw.Text('Resumo dos Indicadores:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: 'Viagens no período: $_totalViagens'),
            pw.Bullet(text: 'Tempo na rota atual: ${_tempoRotaAtual ~/ 60}h ${_tempoRotaAtual % 60}m'),
            pw.Bullet(text: 'Conformidade: ${_conformidade.toStringAsFixed(1)}%'),
            pw.Bullet(text: 'Alertas Recebidos: $_alertasRecebidos'),
            pw.SizedBox(height: 20),
            pw.Text('Lista de Viagens:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (_viagens.isEmpty)
              pw.Text('Nenhuma viagem realizada neste período.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey))
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
                    _buildHeader(context),
                    const SizedBox(height: 16),
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.red.withValues(alpha: 0.1),
                        child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                      ),
                    _buildFiltrosExtras(),
                    const SizedBox(height: 24),
                    _buildPeriodToggle(),
                    const SizedBox(height: 24),
                    _buildMetricsGrid(),
                    const SizedBox(height: 24),
                    _buildChart1(),
                    const SizedBox(height: 24),
                    _buildChart2(),
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: Color(0xFFC23147), size: 28),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isVehicleContext ? 'Relatório — Veículo' : 'Relatório — Frota',
                style: const TextStyle(
                  color: Color(0xFFC23147),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_perfil != null)
                Text(
                  _perfil!.role.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFC23147),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => CustomEndDrawer.showMenu(context),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Image.asset(
              'assets/images/logo.png',
              color: const Color(0xFFC23147),
              width: 44,
              height: 44,
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
        if (_frotas.isNotEmpty) ...[
          const Text('Frota', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC23147))),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            value: _selectedFrotaId, // ignore: deprecated_member_use
            hint: const Text('Todas as frotas'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Todas as frotas')),
              ..._frotas.map((f) => DropdownMenuItem(value: f.id, child: Text(f.nome ?? 'Sem nome'))),
            ],
            onChanged: (val) {
              setState(() {
                _selectedFrotaId = (val == null || val.isEmpty) ? null : val;
                _selectedDispositivoId = null; 
              });
              _loadReportData();
            },
          ),
          const SizedBox(height: 12),
        ],
        if (_dispositivos.isNotEmpty) ...[
          const Text('Dispositivo', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC23147))),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            value: _selectedDispositivoId, // ignore: deprecated_member_use
            hint: const Text('Todos os dispositivos'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Todos os dispositivos')),
              ..._dispositivos.where((d) => _selectedFrotaId == null || d.idFrota == _selectedFrotaId).map((d) => DropdownMenuItem(value: d.id, child: Text(d.nomeDispositivo ?? d.placaVeiculo ?? d.id.substring(0,8)))),
            ],
            onChanged: (val) {
              setState(() {
                _selectedDispositivoId = (val == null || val.isEmpty) ? null : val;
              });
              _loadReportData();
            },
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
      ),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFC23147) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      childAspectRatio: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricCard('Viagens no período', '$_totalViagens'),
        _buildMetricCard('Tempo na rota atual', '${_tempoRotaAtual ~/ 60}h ${_tempoRotaAtual % 60}m'),
        _buildMetricCard('Conformidade', '${_conformidade.toStringAsFixed(1)}%'),
        _buildMetricCard('Alertas recebidos', '$_alertasRecebidos'),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Color(0xFFC23147), fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildChart1() {
    List<FlSpot> spots = [];
    if (_medicoes.isNotEmpty) {
      _medicoes.sort((a,b) => a.registradoEm!.compareTo(b.registradoEm!));
      double start = _medicoes.first.registradoEm!.millisecondsSinceEpoch.toDouble();
      for (var m in _medicoes) {
        if (m.temperatura != null) {
          double x = (m.registradoEm!.millisecondsSinceEpoch.toDouble() - start) / 3600000.0;
          spots.add(FlSpot(x, m.temperatura!.toDouble()));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Temperatura média',
              style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Text('Temperatura', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  Icon(Icons.keyboard_arrow_down, color: Colors.black54, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _medicoes.isEmpty
            ? const Center(child: Text("Sem dados de temperatura", style: TextStyle(color: Colors.black54)))
            : LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFFC23147),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFFC23147).withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildChart2() {
    List<BarChartGroupData> barGroups = [];
    if (_ocorrencias.isNotEmpty) {
      // Aggregate by day inside the period
      Map<int, int> counts = {};
      for(var o in _ocorrencias) {
        if (o.criadoEm != null) {
          int day = o.criadoEm!.day;
          counts[day] = (counts[day] ?? 0) + 1;
        }
      }
      int i = 0;
      counts.forEach((day, count) {
        barGroups.add(BarChartGroupData(
          x: i++,
          barRods: [
            BarChartRodData(toY: count.toDouble(), color: const Color(0xFFC23147), width: 16, borderRadius: BorderRadius.circular(4))
          ]
        ));
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alertas',
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _ocorrencias.isEmpty
            ? const Center(child: Text("Nenhum alerta recebido", style: TextStyle(color: Colors.black54)))
            : BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Could map X to days
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildViagens() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Viagens no período',
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_viagens.isEmpty)
           const Center(child: Text("Nenhuma viagem realizada neste período.", style: TextStyle(color: Colors.black54))),
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
      child: ElevatedButton.icon(
        onPressed: _exportToPDF,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC23147),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.download, color: Colors.white),
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
