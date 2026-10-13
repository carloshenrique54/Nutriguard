import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/widgets/custom_end_drawer.dart';

void main() {
  group('CustomEndDrawer Gerente Fleet-Dependent Options Tests', () {
    Widget createTestWidget({
      required bool hasFleets,
    }) {
      return MaterialApp(
        routes: {
          '/': (context) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => CustomEndDrawer.showMenu(
                      ctx,
                      userRoleOverride: 'gerente',
                      hasFleetsOverride: hasFleets,
                    ),
                    child: const Text('Open Drawer'),
                  ),
                ),
              ),
          '/perfil': (context) => const Scaffold(body: Text('Tela Perfil')),
        },
      );
    }

    testWidgets('1. Gerente without fleet: All fleet-dependent options are locked with Requer frota', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasFleets: false));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Info banner is displayed
      expect(find.text('Nenhuma frota atribuída'), findsOneWidget);
      expect(find.text('As opções que dependem de frota estão indisponíveis.'), findsOneWidget);

      // Requer frota lock badge is displayed for fleet-dependent options
      expect(find.text('Requer frota'), findsWidgets);

      // Tapping a disabled item shows custom feedback SnackBar
      await tester.tap(find.text('Dashboard — Frota'));
      await tester.pump();
      expect(
        find.text('Você não possui nenhuma frota atribuída para acessar esta opção.'),
        findsOneWidget,
      );

      // Account option (Perfil) and Logout remain enabled and available
      await tester.scrollUntilVisible(find.text('Perfil'), 50);
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
    });

    testWidgets('2. Gerente WITH fleet: All options are enabled and banner is hidden', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasFleets: true));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Info banner must NOT be displayed
      expect(find.text('Nenhuma frota atribuída'), findsNothing);

      // No lock badges for manager options
      expect(find.text('Requer frota'), findsNothing);

      // Options are present and enabled
      expect(find.text('Dashboard — Frota'), findsOneWidget);
      expect(find.text('Dashboard — Veículo'), findsOneWidget);
      expect(find.text('Listar frotas'), findsOneWidget);
      expect(find.text('Listar dispositivos'), findsOneWidget);
      expect(find.text('Listar operadores'), findsOneWidget);
      expect(find.text('Alertas — Frota'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Perfil'), 50);
      expect(find.text('Perfil'), findsOneWidget);
    });
  });
}
