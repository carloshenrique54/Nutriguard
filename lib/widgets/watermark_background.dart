import 'package:flutter/material.dart';

class WatermarkBackground extends StatelessWidget {
  final Widget child;
  
  const WatermarkBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fundo bege principal (caso a tela não tenha fundo definido)
        Container(color: const Color(0xFFFFF2E0)),
        
        // Padrão subtil (Watermark)
        Positioned.fill(
          child: Opacity(
            opacity: 0.04, // 4% de opacidade
            child: CustomPaint(
              painter: _WatermarkPainter(),
            ),
          ),
        ),
        
        // Conteúdo da página por cima
        child,
      ],
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Desenhar uma grelha geométrica pontilhada diagonal
    const double step = 40.0;
    
    for (double i = -size.height; i < size.width; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
    for (double i = -size.width; i < size.height; i += step) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i + size.width),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
