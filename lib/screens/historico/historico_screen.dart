import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';

class HistoricoScreen extends StatefulWidget {
  final String userRole;

  const HistoricoScreen({
    super.key,
    this.userRole = 'Operador',
  });

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  List<OcorrenciaModel> _alerts = [];
  String _userRole = '';

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
        if (perfil != null) _userRole = perfil.cargo ?? '';
      }

      final ocorrencias = await _supabase.getOcorrencias();
      ocorrencias.sort((a, b) => (b.criadoEm ?? DateTime.now()).compareTo(a.criadoEm ?? DateTime.now()));
      _alerts = ocorrencias;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Erro: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 3),
      body: WatermarkBackground(
        child: SafeArea(
          child: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFFC23147),
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    await _fetchData();
                  },
                  child: _isLoading
                      ? ListView.builder(
                          itemCount: 4,
                          itemBuilder: (context, index) => const Padding(
                            padding: EdgeInsets.only(bottom: 16.0),
                            child: ShimmerEffect(
                              width: double.infinity,
                              height: 90,
                              borderRadius: 12,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: _alerts.length,
                          itemBuilder: (context, index) {
                            final alert = _alerts[index];
                            final isWarning = (alert.valorRegistrado ?? 0) > 10;
                            final hora = alert.criadoEm != null ? '${alert.criadoEm!.hour}:${alert.criadoEm!.minute}' : '12:00';

                            bool showTimeText = false;
                            if (index == 0) {
                              showTimeText = true;
                            } else {
                              final prevAlert = _alerts[index - 1];
                              final prevHora = prevAlert.criadoEm != null ? '${prevAlert.criadoEm!.hour}:${prevAlert.criadoEm!.minute}' : '12:00';
                              if (prevHora != hora) showTimeText = true;
                            }

                            return AnimatedListItem(
                              index: index,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showTimeText)
                                    _buildTimeText('Hoje - $hora'),
                                  TimelineCard(
                                    title: alert.tipo ?? 'Evento',
                                    location: 'Localização atualizada',
                                    time: hora,
                                    isAlert: isWarning,
                                    extraInfo: alert.status,
                                    icon: isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
                                    iconColor: isWarning ? const Color(0xFFC23147) : const Color(0xFF8DB600),
                                    iconBgColor: isWarning ? const Color(0xFFFFE5E5) : const Color(0xFFE5F5C9),
                                  ),
                                  if (index < _alerts.length - 1)
                                    _buildArrow(),
                                  if (index == _alerts.length - 1)
                                    const SizedBox(height: 24),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
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
          'Histórico',
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

  Widget _buildTimeText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Icon(
          Icons.arrow_downward,
          color: Color(0xFFC23147),
          size: 20,
        ),
      ),
    );
  }
}

class TimelineCard extends StatelessWidget {
  final String title;
  final String location;
  final String time;
  final bool isAlert;
  final String? extraInfo;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const TimelineCard({
    super.key,
    required this.title,
    required this.location,
    required this.time,
    required this.isAlert,
    this.extraInfo,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isAlert 
            ? const Border(left: BorderSide(color: Color(0xFFC23147), width: 4))
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // diffuse
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
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
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFFC23147),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                if (extraInfo != null && extraInfo!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    extraInfo!,
                    style: const TextStyle(
                      color: Color(0xFFC23147),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
