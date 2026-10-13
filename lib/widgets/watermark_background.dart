import 'package:flutter/material.dart';

class WatermarkBackground extends StatelessWidget {
  final Widget child;
  
  const WatermarkBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFFFF2E0),
      child: child,
    );
  }
}
