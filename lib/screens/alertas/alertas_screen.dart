import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../widgets/watermark_background.dart';

class AlertasScreen extends StatelessWidget {
  final String userRole;
  final String? viewContext;
  final bool hasAlerts;

  const AlertasScreen({
    super.key,
    this.userRole = 'ADM',
    this.viewContext = 'Vendo: Frota Sul (6 veículos)',
    this.hasAlerts = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 0),
      body: WatermarkBackground(
        child: SafeArea(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              if (viewContext != null) ...[
                const SizedBox(height: 16),
                _buildViewContext(),
              ],
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
              if (!hasAlerts)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'Nenhum alerta emitido',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              else
                _buildAlertsList(),
              const SizedBox(height: 80), // Padding to account for bottom nav
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
          'Alertas',
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
            userRole,
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

  Widget _buildViewContext() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFC8E569).withAlpha(76), // ~30% opacity
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            color: Color(0xFF8DC63F),
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            viewContext!,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // ~5% opacity diffuse
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF8DC63F),
            radius: 20,
            child: Icon(Icons.check, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status de Operação',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Sensores online e conectados',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFC8E569),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Normal',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
    return Column(
      children: [
        const AlertCard(
          title: 'Porta aberta',
          subtitle: 'Mal fechada',
          time: '14:32',
          accentColor: Color(0xFFC23147),
          iconBgColor: Color(0xFFFFE5E5),
          icon: Icons.door_front_door_outlined,
          timeColor: Color(0xFFC23147),
        ),
        const AlertCard(
          title: 'Aumento da taxa de vibrações',
          subtitle: 'Risco não muito grande',
          time: '09:15',
          accentColor: Color(0xFFF59E0B),
          iconBgColor: Color(0xFFFEF3C7),
          icon: Icons.vibration,
          timeColor: Color(0xFFF59E0B),
        ),
        const AlertCard(
          title: 'Aquecimento',
          subtitle: 'Carga com temperatura acima do limite',
          time: '12:00',
          accentColor: Color(0xFFF59E0B),
          iconBgColor: Color(0xFFFEF3C7),
          icon: Icons.thermostat,
          timeColor: Color(0xFFF59E0B),
        ),
      ],
    );
  }
}

class AlertCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final Color accentColor;
  final Color iconBgColor;
  final IconData icon;
  final Color timeColor;

  const AlertCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.accentColor,
    required this.iconBgColor,
    required this.icon,
    required this.timeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: accentColor,
            width: 4,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // diffuse
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: timeColor,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: timeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
