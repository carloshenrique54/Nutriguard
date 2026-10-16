import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/widgets/custom_end_drawer.dart';

void main() {
  group('CustomEndDrawer Operador Vehicle-Dependent Options Tests', () {
    Widget createTestWidget({
      required bool hasDevices,
    }) {
      return MaterialApp(
        routes: {
          '/': (context) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => CustomEndDrawer.showMenu(
                      ctx,
                      userRoleOverride: 'operador',
                      hasDevicesOverride: hasDevices,
                    ),
                    child: const Text('Open Drawer'),
                  ),
                ),
              ),
          '/perfil': (context) => const Scaffold(body: Text('Tela Perfil')),
        },
      );
    }

    testWidgets('1. Operador without linked vehicle: All vehicle-dependent options are locked with Requer veículo', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasDevices: false));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Info banner is displayed
      expect(find.text('Nenhum veículo vinculado'), findsOneWidget);
      expect(find.text('As opções que dependem de veículo estão indisponíveis.'), findsOneWidget);

      // Requer veículo lock badge is displayed for vehicle-dependent options
      expect(find.text('Requer veículo'), findsWidgets);

      // Options exist
      expect(find.text('Alertas — Veículo'), findsOneWidget);
      expect(find.text('GPS — Veículo'), findsOneWidget);
      expect(find.text('Histórico — Veículo'), findsOneWidget);
      expect(find.text('Relatório — Veículo'), findsOneWidget);
      expect(find.text('Parar viagem'), findsOneWidget);

      // Tapping a disabled item shows custom feedback SnackBar
      await tester.tap(find.text('Alertas — Veículo'));
      await tester.pump();
      expect(
        find.text('Você não possui nenhum veículo vinculado para acessar esta opção.'),
        findsOneWidget,
      );

      // Account option (Perfil) and Logout remain enabled and available
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
    });

    testWidgets('2. Operador without linked vehicle: Tapping locked Parar viagem shows specific feedback message', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasDevices: false));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Scroll to and tap Parar viagem
      await tester.ensureVisible(find.text('Parar viagem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parar viagem'));
      await tester.pump();
      expect(
        find.text('Você não possui nenhum veículo vinculado para parar viagem.'),
        findsOneWidget,
      );
    });

    testWidgets('3. Operador WITH linked vehicle: All options are enabled and banner is hidden', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasDevices: true));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Info banner must NOT be displayed
      expect(find.text('Nenhum veículo vinculado'), findsNothing);

      // No lock badges for vehicle options
      expect(find.text('Requer veículo'), findsNothing);

      // Options are present and enabled
      expect(find.text('Alertas — Veículo'), findsOneWidget);
      expect(find.text('GPS — Veículo'), findsOneWidget);
      expect(find.text('Histórico — Veículo'), findsOneWidget);
      expect(find.text('Relatório — Veículo'), findsOneWidget);
      expect(find.text('Parar viagem'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
    });
  });
}
