import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Painter para o gráfico de temperatura no card Hero do veículo.
/// Suporta valores reais de telemetria, escala dinâmica inteligente, linhas guia e preenchimento gradiente.
class TemperatureMiniChartPainter extends CustomPainter {
  final double? currentTemp;
  final List<double>? dataPoints;
  final List<double>? points;
  final double? minLimit;
  final double? maxLimit;

  TemperatureMiniChartPainter({
    this.currentTemp,
    this.dataPoints,
    this.points,
    this.minLimit,
    this.maxLimit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final pts = points ?? dataPoints ?? [5.0, 5.2, 4.8, 5.1, 4.9, 4.3, currentTemp ?? 5.4];
    if (pts.isEmpty) return;

    // Determina limites e escala dinamicamente com base nas configurações e nos pontos reais
    double minVal = minLimit ?? 2.0;
    double maxVal = maxLimit ?? 8.0;

    for (final p in pts) {
      if (p < minVal) minVal = (p - 0.5).floorToDouble();
      if (p > maxVal) maxVal = (p + 0.5).ceilToDouble();
    }
    if (maxVal <= minVal) {
      maxVal = minVal + 4.0;
    }

    const leftMargin = 22.0;
    const rightMargin = 8.0;
    const topMargin = 8.0;
    const bottomMargin = 8.0;

    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    // Níveis de grade e rótulos
    final yLevels = [
      maxVal,
      minVal + (maxVal - minVal) * 0.5,
      minVal,
    ];

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < yLevels.length; i++) {
      final val = yLevels[i];
      final normalized = ((val - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
      final y = topMargin + chartHeight * (1.0 - normalized);

      // Linha horizontal de grade
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width - rightMargin, y),
        gridPaint,
      );

      // Rótulo do eixo Y
      final labelText = val % 1 == 0 ? '${val.toInt()}°' : '${val.toStringAsFixed(1)}°';
      textPainter.text = TextSpan(
        text: labelText,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 4, y - textPainter.height / 2),
      );
    }

    // Calcula coordenadas dos pontos
    final pointOffsets = <Offset>[];
    for (int i = 0; i < pts.length; i++) {
      final x = leftMargin + (chartWidth * (pts.length > 1 ? (i / (pts.length - 1)) : 0.5));
      final normalized = ((pts[i] - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
      final y = topMargin + chartHeight * (1.0 - normalized);
      pointOffsets.add(Offset(x, y));
    }

    // Cria o caminho suave
    final path = Path();
    for (int i = 0; i < pointOffsets.length; i++) {
      if (i == 0) {
        path.moveTo(pointOffsets[i].dx, pointOffsets[i].dy);
      } else {
        final p0 = pointOffsets[i - 1];
        final p1 = pointOffsets[i];
        final controlX = (p0.dx + p1.dx) / 2;
        path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }
    }

    // Gradiente abaixo da curva (fill)
    if (pointOffsets.isNotEmpty) {
      final fillPath = Path.from(path)
        ..lineTo(pointOffsets.last.dx, topMargin + chartHeight)
        ..lineTo(pointOffsets.first.dx, topMargin + chartHeight)
        ..close();

      final fillGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFC23147).withValues(alpha: 0.35),
          const Color(0xFFC23147).withValues(alpha: 0.0),
        ],
      );

      canvas.drawPath(
        fillPath,
        Paint()..shader = fillGradient.createShader(Rect.fromLTWH(0, topMargin, size.width, chartHeight)),
      );
    }

    // Linha principal de temperatura
    final linePaint = Paint()
      ..color = const Color(0xFFC23147)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Pontos intermediários
    final dotPaint = Paint()
      ..color = const Color(0xFFC23147)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < pointOffsets.length - 1; i++) {
      canvas.drawCircle(pointOffsets[i], 2.0, dotPaint);
    }

    // Destaca o ponto atual com halo/glow
    if (pointOffsets.isNotEmpty) {
      final lastPoint = pointOffsets.last;
      canvas.drawCircle(
        lastPoint,
        6.0,
        Paint()..color = const Color(0xFFC23147).withValues(alpha: 0.25),
      );
      canvas.drawCircle(lastPoint, 3.8, dotPaint);
      canvas.drawCircle(lastPoint, 1.8, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant TemperatureMiniChartPainter oldDelegate) {
    return oldDelegate.currentTemp != currentTemp ||
        oldDelegate.points != points ||
        oldDelegate.minLimit != minLimit ||
        oldDelegate.maxLimit != maxLimit;
  }
}

/// Painter para o mini gráfico de nível de vibração com suporte a telemetria real.
class VibrationMiniChartPainter extends CustomPainter {
  final List<double>? values;
  final double? limit;
  final double? currentVibration;

  VibrationMiniChartPainter({
    this.values,
    this.limit,
    this.currentVibration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final pts = (values != null && values!.isNotEmpty)
        ? values!
        : [0.15, 0.22, 0.18, 0.35, 0.24, 0.19, currentVibration ?? 0.25];

    final double maxLimit = limit ?? 2.0;

    // Encontra pico dos dados para escala vertical
    double peakVal = maxLimit;
    bool hasNegative = false;
    for (final v in pts) {
      if (v.abs() > peakVal) peakVal = v.abs();
      if (v < 0) hasNegative = true;
    }
    peakVal = (peakVal * 1.25).clamp(1.0, 10.0);

    const leftMargin = 22.0;
    const rightMargin = 6.0;
    const topMargin = 6.0;
    const bottomMargin = 6.0;

    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    // Linha de Limite de Vibração
    final double limitNormalized = (maxLimit / peakVal).clamp(0.0, 1.0);
    final double limitY = topMargin + chartHeight * (1.0 - limitNormalized);

    final limitPaint = Paint()
      ..color = const Color(0xFFD97706).withValues(alpha: 0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    _drawDashedLine(
      canvas,
      Offset(leftMargin, limitY),
      Offset(size.width - rightMargin, limitY),
      limitPaint,
      dashWidth: 4,
      dashSpace: 3,
    );

    // Texto do limite no eixo Y
    textPainter.text = TextSpan(
      text: '${maxLimit.toStringAsFixed(1)}G',
      style: const TextStyle(
        color: Color(0xFFD97706),
        fontSize: 8,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(leftMargin - textPainter.width - 3, limitY - textPainter.height / 2),
    );

    // Linha de base zero
    final double zeroY = hasNegative ? (topMargin + chartHeight / 2) : (topMargin + chartHeight);
    final baselinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(leftMargin, zeroY), Offset(size.width - rightMargin, zeroY), baselinePaint);

    // Rótulo da base 0G
    textPainter.text = const TextSpan(
      text: '0G',
      style: TextStyle(
        color: Colors.black45,
        fontSize: 8,
        fontWeight: FontWeight.w600,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(leftMargin - textPainter.width - 3, zeroY - textPainter.height / 2),
    );

    // Mapeamento dos pontos
    final pointOffsets = <Offset>[];
    for (int i = 0; i < pts.length; i++) {
      final x = leftMargin + (chartWidth * (pts.length > 1 ? (i / (pts.length - 1)) : 0.5));
      final val = pts[i];
      final double norm;
      if (hasNegative) {
        norm = (val / peakVal).clamp(-1.0, 1.0);
      } else {
        norm = (val / peakVal).clamp(0.0, 1.0);
      }
      final y = hasNegative
          ? zeroY - (norm * (chartHeight / 2))
          : zeroY - (norm * chartHeight);
      pointOffsets.add(Offset(x, y.clamp(topMargin, topMargin + chartHeight)));
    }

    final bool isExceeded = (pts.isNotEmpty && pts.last.abs() > maxLimit);
    final Color strokeColor = isExceeded ? const Color(0xFFC23147) : const Color(0xFF0D9488);

    // Traçado da curva
    final path = Path();
    for (int i = 0; i < pointOffsets.length; i++) {
      if (i == 0) {
        path.moveTo(pointOffsets[i].dx, pointOffsets[i].dy);
      } else {
        final p0 = pointOffsets[i - 1];
        final p1 = pointOffsets[i];
        final controlX = (p0.dx + p1.dx) / 2;
        path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }
    }

    // Preenchimento gradiente
    if (pointOffsets.isNotEmpty) {
      final fillPath = Path.from(path)
        ..lineTo(pointOffsets.last.dx, zeroY)
        ..lineTo(pointOffsets.first.dx, zeroY)
        ..close();

      final fillGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          strokeColor.withValues(alpha: 0.25),
          strokeColor.withValues(alpha: 0.0),
        ],
      );
      canvas.drawPath(
        fillPath,
        Paint()..shader = fillGradient.createShader(Rect.fromLTWH(0, topMargin, size.width, chartHeight)),
      );
    }

    // Linha principal
    final wavePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, wavePaint);

    // Ponto mais recente com destaque
    if (pointOffsets.isNotEmpty) {
      final lastPoint = pointOffsets.last;
      canvas.drawCircle(
        lastPoint,
        5.0,
        Paint()..color = strokeColor.withValues(alpha: 0.25),
      );
      canvas.drawCircle(lastPoint, 3.2, Paint()..color = strokeColor);
      canvas.drawCircle(lastPoint, 1.5, Paint()..color = Colors.white);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, {double dashWidth = 4, double dashSpace = 3}) {
    double currentX = p1.dx;
    final double endX = p2.dx;
    while (currentX < endX) {
      final double nextX = math.min(currentX + dashWidth, endX);
      canvas.drawLine(Offset(currentX, p1.dy), Offset(nextX, p1.dy), paint);
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant VibrationMiniChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.limit != limit ||
        oldDelegate.currentVibration != currentVibration;
  }
}

/// Widget vetorial que renderiza a silhueta estilizada de um caminhão de entrega moderno.
class DeliveryTruckGraphic extends StatelessWidget {
  final double width;
  final double height;

  const DeliveryTruckGraphic({
    super.key,
    this.width = 90,
    this.height = 45,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _DeliveryTruckPainter(),
      ),
    );
  }
}

class _DeliveryTruckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sombra do caminhão
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.92), width: w * 0.9, height: h * 0.15),
      shadowPaint,
    );

    // Baú de carga (retângulo branco com borda e linhas sutis)
    final cargoRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.1, w * 0.74, h * 0.65),
      const Radius.circular(3),
    );
    final cargoPaint = Paint()..color = Colors.white;
    final borderPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(cargoRect, cargoPaint);
    canvas.drawRRect(cargoRect, borderPaint);

    // Divisória do baú
    canvas.drawLine(
      Offset(w * 0.22, h * 0.75),
      Offset(w * 0.96, h * 0.75),
      borderPaint,
    );

    // Cabine do motorista (à esquerda)
    final cabPath = Path();
    cabPath.moveTo(w * 0.22, h * 0.75);
    cabPath.lineTo(w * 0.04, h * 0.75); // base
    cabPath.lineTo(w * 0.04, h * 0.42); // frente
    cabPath.lineTo(w * 0.12, h * 0.22); // parabrisa inclinado
    cabPath.lineTo(w * 0.22, h * 0.22); // teto
    cabPath.close();

    final cabPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawPath(cabPath, cabPaint);
    canvas.drawPath(cabPath, borderPaint);

    // Janela da cabine
    final windowPath = Path();
    windowPath.moveTo(w * 0.11, h * 0.42);
    windowPath.lineTo(w * 0.20, h * 0.42);
    windowPath.lineTo(w * 0.20, h * 0.26);
    windowPath.lineTo(w * 0.13, h * 0.26);
    windowPath.close();

    final windowPaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawPath(windowPath, windowPaint);

    // Farol dianteiro
    final headlightPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.04, h * 0.52, w * 0.02, h * 0.08), const Radius.circular(1)),
      headlightPaint,
    );

    // Rodas (pneus pretos com calota cinza)
    final wheelPaint = Paint()..color = const Color(0xFF1E293B);
    final rimPaint = Paint()..color = const Color(0xFFCBD5E1);

    final wheelRadius = h * 0.13;

    // Roda dianteira
    final frontWheelCenter = Offset(w * 0.14, h * 0.78);
    canvas.drawCircle(frontWheelCenter, wheelRadius, wheelPaint);
    canvas.drawCircle(frontWheelCenter, wheelRadius * 0.5, rimPaint);

    // Rodas traseiras duplas
    final rearWheelCenter1 = Offset(w * 0.72, h * 0.78);
    final rearWheelCenter2 = Offset(w * 0.88, h * 0.78);
    canvas.drawCircle(rearWheelCenter1, wheelRadius, wheelPaint);
    canvas.drawCircle(rearWheelCenter1, wheelRadius * 0.5, rimPaint);
    canvas.drawCircle(rearWheelCenter2, wheelRadius, wheelPaint);
    canvas.drawCircle(rearWheelCenter2, wheelRadius * 0.5, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
