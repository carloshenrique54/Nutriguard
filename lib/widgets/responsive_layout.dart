import 'package:flutter/material.dart';

/// Constantes e breakpoints de responsividade para o Nutriguard.
class ResponsiveBreakpoints {
  static const double mobile = 600.0;
  static const double desktop = 900.0;
  static const double maxContentWidth = 1200.0;
  static const double maxFormWidth = 680.0;
  static const double maxAuthWidth = 480.0;
}

/// Helper para verificar o formato de tela atual a partir do contexto.
class ResponsiveLayoutHelper {
  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < ResponsiveBreakpoints.mobile;
  }

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= ResponsiveBreakpoints.mobile && w < ResponsiveBreakpoints.desktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= ResponsiveBreakpoints.desktop;
  }
}

/// Wrapper que centraliza e limita a largura máxima do conteúdo em telas grandes (Desktop/Tablet),
/// mantendo preenchimento fluido e adaptado em telas móveis.
class ResponsiveContentWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return content;
  }
}

/// Constrói layouts alternativos com base nas restrições de largura (LayoutBuilder).
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints) mobile;
  final Widget Function(BuildContext context, BoxConstraints constraints)? tablet;
  final Widget Function(BuildContext context, BoxConstraints constraints) desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.desktop) {
          return desktop(context, constraints);
        } else if (constraints.maxWidth >= ResponsiveBreakpoints.mobile && tablet != null) {
          return tablet!(context, constraints);
        } else {
          return mobile(context, constraints);
        }
      },
    );
  }
}
