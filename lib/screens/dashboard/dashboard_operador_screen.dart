import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../widgets/watermark_background.dart';

class DashboardOperadorScreen extends StatefulWidget {
  const DashboardOperadorScreen({super.key});

  @override
  State<DashboardOperadorScreen> createState() => _DashboardOperadorScreenState();
}

class _DashboardOperadorScreenState extends State<DashboardOperadorScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  String _userRole = '';
  List<OcorrenciaModel> _alerts = [];

  double _currentTemp = 0.0;
  bool _hasActiveTrip = false;
  String _activeTripDuration = '0h 0m';

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = _supabase.currentUser?.id;
      if (currentUserId == null) return;
      
      final perfil = await _supabase.getUsuarioPerfil(currentUserId);
      if (perfil != null) _userRole = perfil.cargo ?? '';

      final dispositivos = await _supabase.getDispositivosByOperador(currentUserId);
      List<String> deviceIds = dispositivos.map((d) => d.id).toList();

      DateTime agora = DateTime.now();
      DateTime inicio = agora.subtract(const Duration(days: 30));
      
      final ocorrencias = await _supabase.getOcorrenciasFiltro(deviceIds, inicio, agora);
      ocorrencias.sort((a, b) => (b.criadoEm ?? DateTime.now()).compareTo(a.criadoEm ?? DateTime.now()));
      _alerts = ocorrencias.take(5).toList();

      final medicoes = await _supabase.getMedicoesFiltro(deviceIds, inicio, agora);
      
      if (medicoes.isNotEmpty) {
        medicoes.sort((a, b) => a.registradoEm!.compareTo(b.registradoEm!));
        final last = medicoes.last;
        _currentTemp = last.temperatura?.toDouble() ?? 0.0;
        
        DateTime first = medicoes.first.registradoEm!;
        bool ativa = agora.difference(last.registradoEm!).inHours < 2;
        _hasActiveTrip = ativa;
        if (ativa) {
          int duracao = agora.difference(first).inMinutes;
          _activeTripDuration = '${duracao ~/ 60}h ${duracao % 60}m';
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Erro: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAccess() async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final perfil = await _supabase.getUsuarioPerfil(currentUserId);
    final role = perfil?.role ?? '';
    
    List<String> allowedRoles = ['operador'];

    if (!allowedRoles.contains(role)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acesso negado para seu perfil', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 2),
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
                  _buildTemperatureCard(),
                  const SizedBox(height: 16),
                  _buildInfoGrid(),
                  const SizedBox(height: 16),
                  _buildStatusBanner(),
                  const SizedBox(height: 16),
                  _buildRecentEvents(),
                  const SizedBox(height: 60), // Extra space for BottomAppBar
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
        const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 28,
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),
        Builder(
          builder: (context) => GestureDetector(
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
        ),
      ],
    );
  }

  Widget _buildTemperatureCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Left Side
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 28,
                  child: Icon(
                    Icons.thermostat,
                    color: Color(0xFFC23147),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Temperatura',
                      style: TextStyle(color: Colors.black87, fontSize: 16),
                    ),
                    Text('${_currentTemp.toStringAsFixed(1)}°C', style: const TextStyle(
                        color: Colors.black,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Dentro do limite',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right Side (Chart Placeholder)
          Expanded(
            flex: 2,
            child: Container(
              height: 80,
              alignment: Alignment.center,
              child: const Icon(
                Icons.show_chart,
                color: Color(0xFFC23147),
                size: 60,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildInfoCard(
          icon: Icons.access_time,
          title: 'Tempo de rota',
          value: _activeTripDuration,
          subtitle: 'Viagem atual',
          color: Colors.blue,
        ),
        _buildInfoCard(
          icon: Icons.directions_car,
          title: 'Status do veículo',
          value: _hasActiveTrip ? 'Em andamento' : 'Parado',
          subtitle: _hasActiveTrip ? 'Em trânsito' : 'Finalizado',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 20,
            child: Icon(Icons.check, color: Colors.green, size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carga em condições normais',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Todos os parametros estão dentro dos limites',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.local_shipping, size: 40, color: Colors.black87),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/alertas-veiculo'),
              child: const Text('Ver todos', style: TextStyle(color: Color(0xFFC23147), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: _alerts.isEmpty 
            ? const Center(child: Text("Nenhum evento recente", style: TextStyle(color: Colors.black54)))
            : Column(
                children: _alerts.map((alerta) {
                  return Column(
                    children: [
                      _buildEventRow(
                        icon: Icons.warning_amber_rounded,
                        title: alerta.tipo ?? 'Alerta',
                        subtitle: 'Valor: ${alerta.valorRegistrado ?? '-'}',
                        time: alerta.criadoEm != null ? '${alerta.criadoEm!.day}/${alerta.criadoEm!.month} ${alerta.criadoEm!.hour}:${alerta.criadoEm!.minute.toString().padLeft(2, '0')}' : '',
                      ),
                      if (alerta != _alerts.last) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                    ],
                  );
                }).toList(),
              ),
        ),
      ],
    );
  }

  Widget _buildEventRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFC8E569).withValues(alpha: 0.3),
          radius: 20,
          child: Icon(icon, color: Colors.green, size: 20),
        ),
        const SizedBox(width: 12),
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
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFFC23147)),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Icon(Icons.access_time, color: Color(0xFFC23147), size: 16),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// COMPONENTES MODULARES (ESPECÍFICOS DESTA TELA)
// ---------------------------------------------------------

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final double valueSize;
  final Widget? bottomWidget;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.valueSize = 24,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, 4),
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
            child: Icon(icon, color: const Color(0xFFC23147), size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: const Color(0xFFC23147),
                fontSize: valueSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          ?bottomWidget,
        ],
      ),
    );
  }
}
