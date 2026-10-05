import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';

class DashboardAdmFrotaScreen extends StatefulWidget {
  const DashboardAdmFrotaScreen({super.key});

  @override
  State<DashboardAdmFrotaScreen> createState() => _DashboardAdmFrotaScreenState();
}

class _DashboardAdmFrotaScreenState extends State<DashboardAdmFrotaScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  String _userName = 'Admin';
  String _userRole = 'ADM';
  int _devicesCount = 0;
  List<FrotaModel> _frotas = [];
  Map<String, int> _frotaDeviceCounts = {};
  List<OcorrenciaModel> _alerts = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = _supabase.currentUser?.id;
      if (currentUserId != null) {
        final perfil = await _supabase.getUsuarioPerfil(currentUserId);
        if (perfil != null) {
          _userName = perfil.nome ?? 'Admin';
          _userRole = perfil.cargo ?? 'ADM';
        }
      }

      final frotas = await _supabase.getFrotas();
      final dispositivos = await _supabase.getDispositivos();
      final ocorrencias = await _supabase.getOcorrencias();

      _frotas = frotas;
      _devicesCount = dispositivos.length;

      Map<String, int> counts = {};
      for (var f in frotas) {
        counts[f.id] = dispositivos.where((d) => d.idFrota == f.id).length;
      }
      _frotaDeviceCounts = counts;

      // Pegar as 5 ultimas ocorrencias (simulado)
      ocorrencias.sort((a, b) => (b.criadoEm ?? DateTime.now()).compareTo(a.criadoEm ?? DateTime.now()));
      _alerts = ocorrencias.take(5).toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Erro no dashboard adm: $e');
      if (mounted) setState(() => _isLoading = false);
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
                  _buildManagementCard(),
                  const SizedBox(height: 16),
                  _buildMetricsGrid(),
                  const SizedBox(height: 16),
                  _buildOtherFleets(),
                  const SizedBox(height: 16),
                  _buildRecentEvents(),
                  const SizedBox(height: 60), // Space for BottomAppBar
                ],
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              builder: (ctx) => GestureDetector(
                onTap: () => CustomEndDrawer.showMenu(context),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Image.asset(
                    'assets/images/logo.png',
                    color: const Color(0xFFC23147),
                    width: 32,
                    height: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFC8E569).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: Color(0xFF8DB600),
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Bem vindo, ',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            Text(
              _userName,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManagementCard() {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gerenciamento de frota',
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 4),
                AnimatedCounterText(
                  value: _devicesCount,
                  suffix: ' Veículos',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusIndicator(Colors.green, '$_devicesCount Normais'),
                const SizedBox(height: 4),
                _buildStatusIndicator(Colors.orange, '0 Atenção'),
                const SizedBox(height: 4),
                _buildStatusIndicator(Colors.red, '0 Crítico'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InfoCard(
                title: 'Temperatura média',
                value: '8°C',
                bottomTag: 'Última atualização 1 minuto(s) atrás',
                tagColor: Colors.grey.shade200,
                tagTextColor: Colors.black54,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InfoCard(
                title: 'Umidade média',
                value: '32%',
                bottomTag: 'Dentro do limite',
                tagColor: const Color(0xFFC8E569),
                tagTextColor: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: 'Veículos online hoje',
          value: '$_devicesCount/$_devicesCount',
          bottomTag: 'Limite definido: 40%',
          tagColor: Colors.grey.shade200,
          tagTextColor: Colors.black54,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildOtherFleets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Frotas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Ver todas >',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC23147),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
            children: _frotas.map((f) {
              final dCount = _frotaDeviceCounts[f.id] ?? 0;
              return Column(
                children: [
                  _buildFleetRow(f.nome ?? 'Sem Nome', '$dCount Veículos', dCount, 0, 0),
                  const Divider(height: 1, color: Colors.black12),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFleetRow(
    String title,
    String subtitle,
    int greenCount,
    int yellowCount,
    int redCount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          Row(
            children: [
              _buildCounterBadge(Colors.green, greenCount),
              const SizedBox(width: 8),
              _buildCounterBadge(Colors.orange, yellowCount),
              const SizedBox(width: 8),
              _buildCounterBadge(Colors.red, redCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterBadge(Color color, int count) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        count.toString(),
        style: TextStyle(
          color: color == Colors.orange ? Colors.deepOrange : color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Ver todos >',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC23147),
                ),
              ),
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
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: _alerts.map((alert) {
              return Column(
                children: [
                  _buildEventRow(
                    icon: (alert.valorRegistrado ?? 0) > 10 ? Icons.warning : Icons.info_outline,
                    title: alert.tipo ?? 'Evento',
                    subtitle: alert.status ?? 'Registrado',
                    time: alert.criadoEm != null ? '${alert.criadoEm!.hour}:${alert.criadoEm!.minute}' : '12:00',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 1, color: Colors.black12),
                  ),
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
          backgroundColor: const Color(0xFFC8E569).withOpacity(0.3),
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
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFFC23147)),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Icon(Icons.access_time, color: Color(0xFFC23147), size: 14),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
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
  final String title;
  final String value;
  final String bottomTag;
  final Color tagColor;
  final Color tagTextColor;
  final bool isFullWidth;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.bottomTag,
    required this.tagColor,
    required this.tagTextColor,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isFullWidth ? double.infinity : null,
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFC23147),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              bottomTag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: tagTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
