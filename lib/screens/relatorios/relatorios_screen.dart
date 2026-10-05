import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../widgets/watermark_background.dart';

class RelatoriosScreen extends StatelessWidget {
  final String userRole;

  const RelatoriosScreen({
    super.key,
    this.userRole = 'Operador',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF2E0),
      
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 1),
      body: WatermarkBackground(
        child: SafeArea(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
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
          'Relatório',
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
                'assets/images/logo.png',
                errorBuilder: (ctx, error, stackTrace) =>
                    const Icon(Icons.local_shipping_outlined, color: Color(0xFFC23147), size: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFC23147),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Dia',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Semana',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Mês',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ReportMetricCard(
                icon: Icons.map_outlined,
                title: 'Viagens no período',
                value: '0',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ReportMetricCard(
                icon: Icons.access_time,
                title: 'Tempo na rota atual',
                value: '5h30',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ReportMetricCard(
                icon: Icons.check,
                title: 'Conformidade',
                value: '94%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ReportMetricCard(
                icon: Icons.warning_amber_rounded,
                title: 'Alertas recebidos',
                value: '3',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChart1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Temperatura média',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
                  Text(
                    'Temperatura',
                    style: TextStyle(color: Colors.black87, fontSize: 12),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down,
                      size: 16, color: Colors.black54),
                ],
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Limite: 8ºC',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                width: double.infinity,
                child: CustomPaint(
                  painter: MockLineChartPainter(),
                ),
              ),
              const SizedBox(height: 8),
              _buildChartXAxis(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alertas',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 120,
                width: double.infinity,
                child: CustomPaint(
                  painter: MockBarChartPainter(),
                ),
              ),
              const SizedBox(height: 8),
              _buildChartXAxis(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartXAxis() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('7:50\n(Início)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 8)),
        Text('8:55', style: TextStyle(color: Colors.black45, fontSize: 8)),
        Text('10:00', style: TextStyle(color: Colors.black45, fontSize: 8)),
        Text('11:05', style: TextStyle(color: Colors.black45, fontSize: 8)),
        Text('12:10', style: TextStyle(color: Colors.black45, fontSize: 8)),
        Text('13:15', style: TextStyle(color: Colors.black45, fontSize: 8)),
        Text('14:20\n(Agora)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 8)),
      ],
    );
  }

  Widget _buildViagens() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Viagens',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: const Text(
              'Nenhuma viagem realizada',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC23147),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: () {},
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Exportar PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ReportMetricCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // diffuse
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
              color: const Color(0xFFC23147),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
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
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// CUSTOM PAINTERS PARA GRÁFICOS (MOCK)
// ---------------------------------------------------------

class MockLineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Linha limite (Dashed)
    final dashPaint = Paint()
      ..color = const Color(0xFFC23147)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    double dashY = size.height * 0.4;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, dashY), Offset(x + 5, dashY), dashPaint);
    }

    // Linha do gráfico
    final linePaint = Paint()
      ..color = const Color(0xFFC8E569) // Verde Claro
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.lineTo(size.width * 0.16, size.height * 0.7);
    path.lineTo(size.width * 0.33, size.height * 0.75);
    path.lineTo(size.width * 0.5, size.height * 0.6);
    // Pico (Cruza a linha limite)
    path.lineTo(size.width * 0.66, size.height * 0.2); 
    path.lineTo(size.width * 0.83, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.65);
    
    canvas.drawPath(path, linePaint);

    // Ponto vermelho no pico
    final dotPaint = Paint()..color = const Color(0xFFC23147);
    canvas.drawCircle(Offset(size.width * 0.66, size.height * 0.2), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MockBarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 4 Linhas horizontais (Dashed)
    final dashPaint = Paint()
      ..color = const Color(0xFFC23147)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < 4; i++) {
      double y = size.height * (i / 3);
      for (double x = 0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(x + 5, y), dashPaint);
      }
    }

    // 2 Barras de alerta
    final barPaint = Paint()
      ..color = const Color(0xFFC23147)
      ..style = PaintingStyle.fill;
    
    // Barra as 10:00 (~33% do X)
    final rrect1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.33 - 6, size.height * 0.5, 12, size.height * 0.5), 
      const Radius.circular(4)
    );
    canvas.drawRRect(rrect1, barPaint);

    // Barra as 12:10 (~66% do X)
    final rrect2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.66 - 6, size.height * 0.3, 12, size.height * 0.7), 
      const Radius.circular(4)
    );
    canvas.drawRRect(rrect2, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
