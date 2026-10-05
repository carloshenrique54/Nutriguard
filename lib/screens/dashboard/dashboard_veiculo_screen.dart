import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../repository/app_repository.dart';
import '../../widgets/watermark_background.dart';

class DashboardVeiculoScreen extends StatelessWidget {
  const DashboardVeiculoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      
      backgroundColor: const Color(0xFFFFF2E0),
      
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 2),
      body: WatermarkBackground(
        child: SafeArea(
          child: ListenableBuilder(
          listenable: AppRepository.instance,
          builder: (context, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildSubHeader(),
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
            );
          }
        ),
        ),
      ),
    );
  }


  Widget _buildHeader(BuildContext context) {
    final user = AppRepository.instance.currentUser;
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
            user?.role.toUpperCase() ?? 'GERENTE',
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
              width: 40,
              height: 40,
              child: Image.asset(
                'nutriguard1/web/icons/1.png',
                errorBuilder: (ctx, error, stackTrace) =>
                    const Icon(Icons.apple, color: Color(0xFFC23147), size: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubHeader() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const Text(
              'Vendo: ',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const Text(
              'Volvo FH 540',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
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
                    const Text(
                      '5,4°C',
                      style: TextStyle(
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

  Widget _buildInfoGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InfoCard(
                icon: Icons.shield_outlined,
                title: 'Limite definido',
                value: '8°C',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InfoCard(
                icon: Icons.access_time,
                title: 'Última atualização',
                value: '1 minuto(s) atrás',
                valueSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InfoCard(
                icon: Icons.water_drop_outlined,
                title: 'Nivel de umidade',
                value: '32%',
                bottomWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E569),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Dentro do limite',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Limite definido: 40%',
                      style: TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InfoCard(
                icon: Icons.widgets_outlined,
                title: 'Nivel de vibração',
                value: '',
                bottomWidget: const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Icon(
                    Icons.stacked_line_chart,
                    color: Color(0xFFC23147),
                    size: 40,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InfoCard(
                icon: Icons.door_front_door_outlined,
                title: 'Compartimento',
                value: '',
                bottomWidget: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8E569),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Fechado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InfoCard(
                icon: Icons.battery_charging_full,
                title: 'Bateria',
                value: '78%',
              ),
            ),
          ],
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
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 20,
            child: Icon(Icons.check, color: Colors.green, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
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
          const SizedBox(width: 8),
          const Icon(Icons.local_shipping, size: 40, color: Colors.black87),
        ],
      ),
    );
  }

  Widget _buildRecentEvents() {
    final alerts = AppRepository.instance.alerts;
    
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
            children: alerts.map((alert) {
              return Column(
                children: [
                  _buildEventRow(
                    icon: alert.gravidade == 'alta' ? Icons.warning : Icons.info_outline,
                    title: alert.titulo,
                    subtitle: alert.subtitulo,
                    time: alert.hora,
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
