import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../widgets/watermark_background.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';


class AlertasScreen extends StatefulWidget {
  final String userRole;
  final String? viewContext;

  const AlertasScreen({
    super.key,
    this.userRole = 'ADM',
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

  String _periodoSelecionado = 'Todos';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.currentUser;
      if (user != null) {
        _perfil = await _supabase.getUsuarioPerfil(user.id);
        if (_perfil != null) {
          if (_perfil!.role == 'admin' || _perfil!.role == 'gerente') {
            List<FrotaModel> frotas = _perfil!.role == 'admin' 
              ? await _supabase.getFrotas()
              : await _supabase.getFrotasByGerente(_perfil!.id);
            
            for (var f in frotas) {
              final devs = await _supabase.getDispositivosByFrota(f.id);
              _dispositivos.addAll(devs);
            }
          } else {
            _dispositivos = await _supabase.getDispositivosByOperador(_perfil!.id);
          }
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
    
    List<String> deviceIds = _dispositivos.map((d) => d.id).toList();
    _ocorrencias = await _supabase.getOcorrenciasFiltro(deviceIds, inicio, agora);
    _ocorrencias.sort((a,b) => (b.criadoEm ?? agora).compareTo(a.criadoEm ?? agora));
    
    if (mounted) setState((){});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 0), // Assuming Alertas is index 0 in this specific context or keep 0
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
                    if (_perfil != null) ...[
                      const SizedBox(height: 16),
                      _buildViewContext('Vendo: ${_perfil!.role.toUpperCase()} (${_dispositivos.length} veículos)'),
                    ],
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
                            'Nenhum alerta encontrado.',
                            style: TextStyle(fontSize: 16, color: Colors.black54),
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

  Widget _buildHeader(BuildContext context) {
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
            const Text(
              'Alertas',
              style: TextStyle(
                color: Color(0xFFC23147),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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

  Widget _buildViewContext(String contextText) {
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
            contextText,
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
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Em um cenário real, abrir detalhes do alerta
          },
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
                        'Disp: ${o.idDispositivo?.substring(0,8) ?? 'N/D'} | Valor: ${o.valorRegistrado ?? '-'}',
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
                      o.criadoEm != null ? '${o.criadoEm!.day}/${o.criadoEm!.month} ${o.criadoEm!.hour}:${o.criadoEm!.minute.toString().padLeft(2,'0')}' : '',
                      style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
