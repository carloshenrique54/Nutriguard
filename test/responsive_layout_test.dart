import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/widgets/responsive_layout.dart';

void main() {
  group('Responsive Layout Tests', () {
    testWidgets('ResponsiveContentWrapper respeita maxWidth em telas grandes', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContentWrapper(
              maxWidth: 600,
              child: SizedBox(
                key: Key('inner_child'),
                width: double.infinity,
                height: 100,
              ),
            ),
          ),
        ),
      );

      final innerChildSize = tester.getSize(find.byKey(const Key('inner_child')));
      expect(innerChildSize.width, 600);
    });

    testWidgets('ResponsiveContentWrapper preenche largura total quando menor que maxWidth', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContentWrapper(
              maxWidth: 600,
              child: SizedBox(
                key: Key('inner_child'),
                width: double.infinity,
                height: 100,
              ),
            ),
          ),
        ),
      );

      final innerChildSize = tester.getSize(find.byKey(const Key('inner_child')));
      expect(innerChildSize.width, 400);
    });

    testWidgets('ResponsiveBuilder seleciona builder móvel para larguras < 600', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              mobile: (context, constraints) => const Text('Versão Mobile'),
              desktop: (context, constraints) => const Text('Versão Desktop'),
            ),
          ),
        ),
      );

      expect(find.text('Versão Mobile'), findsOneWidget);
      expect(find.text('Versão Desktop'), findsNothing);
    });

    testWidgets('ResponsiveBuilder seleciona builder desktop para larguras >= 900', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              mobile: (context, constraints) => const Text('Versão Mobile'),
              desktop: (context, constraints) => const Text('Versão Desktop'),
            ),
          ),
        ),
      );

      expect(find.text('Versão Desktop'), findsOneWidget);
      expect(find.text('Versão Mobile'), findsNothing);
    });
  });
}
