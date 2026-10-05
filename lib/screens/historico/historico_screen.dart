import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../repository/app_repository.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _simulateLoading();
  }

  Future<void> _simulateLoading() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _isLoading = false);
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
          child: ListenableBuilder(
            listenable: AppRepository.instance,
            builder: (context, child) {
              final alerts = AppRepository.instance.alerts;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  Expanded(
                    child: RefreshIndicator(
                      color: const Color(0xFFC23147),
                      onRefresh: () async {
                        HapticFeedback.lightImpact();
                        await _simulateLoading();
                      },
                      child: _isLoading
                          ? ListView.builder(
                              itemCount: 4,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: ShimmerEffect(
                                  width: double.infinity,
                                  height: 90,
                                  borderRadius: 12,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: alerts.length,
                              itemBuilder: (context, index) {
                                final alert = alerts[index];
                                final isWarning = alert.gravidade == 'alta';

                                return AnimatedListItem(
                                  index: index,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (index == 0 || alerts[index - 1].hora != alert.hora)
                                        _buildTimeText('Hoje - ${alert.hora}'),
                                      TimelineCard(
                                        title: alert.titulo,
                                        location: 'Localização atualizada',
                                        time: alert.hora,
                                        isAlert: isWarning,
                                        extraInfo: alert.subtitulo,
                                        icon: isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
                                        iconColor: isWarning ? const Color(0xFFC23147) : const Color(0xFF8DB600),
                                        iconBgColor: isWarning ? const Color(0xFFFFE5E5) : const Color(0xFFE5F5C9),
                                      ),
                                      if (index < alerts.length - 1)
                                        _buildArrow(),
                                      if (index == alerts.length - 1)
                                        const SizedBox(height: 24),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
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
            AppRepository.instance.currentUser?.role.toUpperCase() ?? 'OPERADOR',
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
                'web/icons/1.png',
                errorBuilder: (ctx, error, stackTrace) =>
                    Image.asset('web/icons/1.png', width: 32, height: 32),
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
