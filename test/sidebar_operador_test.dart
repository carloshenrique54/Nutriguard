import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutriguard1/widgets/custom_end_drawer.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CustomEndDrawer Operador Vehicle-Dependent Options Tests', () {
    Widget createTestWidget({
      required bool hasDevices,
      bool? isTripActive,
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
                      isTripActiveOverride: isTripActive,
                    ),
                    child: const Text('Open Drawer'),
                  ),
                ),
              ),
          '/perfil': (context) => const Scaffold(body: Text('Tela Perfil')),
          '/login': (context) => const Scaffold(body: Text('Tela Login')),
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
      expect(find.text('Iniciar viagem'), findsOneWidget);

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

    testWidgets('2. Operador without linked vehicle: Tapping locked Iniciar viagem shows specific feedback message', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasDevices: false, isTripActive: false));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Iniciar viagem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar viagem'));
      await tester.pump();
      expect(
        find.text('Você não possui nenhum veículo vinculado para iniciar viagem.'),
        findsOneWidget,
      );
    });

    testWidgets('3. Operador without linked vehicle: Tapping locked Parar viagem shows specific feedback message', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasDevices: false, isTripActive: true));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

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

      await tester.pumpWidget(createTestWidget(hasDevices: true, isTripActive: false));
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
      expect(find.text('Iniciar viagem'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
    });

    testWidgets('4. Operador WITH linked vehicle and active trip: Parar viagem is present and enabled', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasDevices: true, isTripActive: true));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('Parar viagem'), findsOneWidget);
      expect(find.text('Requer veículo'), findsNothing);
    });

    testWidgets('5. Operador with active trip: Tapping Sair shows warning dialog about ending the trip and can cancel', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasDevices: true, isTripActive: true));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Tap Sair in the drawer footer
      await tester.ensureVisible(find.text('Sair'));
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      // Warning dialog appears
      expect(find.text('Viagem em Andamento'), findsOneWidget);
      expect(
        find.text('Você possui uma viagem em andamento. Ao fazer logout, a sua viagem será finalizada automaticamente. Deseja realmente sair e parar a viagem?'),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Sair e Parar Viagem'), findsOneWidget);

      // Tap Cancelar
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Dialog is dismissed, user is still in the drawer and NOT logged out
      expect(find.text('Viagem em Andamento'), findsNothing);
      expect(find.text('Tela Login'), findsNothing);
      expect(find.text('Sair'), findsOneWidget);
    });

    testWidgets('6. Operador with active trip: Confirming Sair stops trip and navigates to /login', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasDevices: true, isTripActive: true));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Tap Sair
      await tester.ensureVisible(find.text('Sair'));
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(find.text('Viagem em Andamento'), findsOneWidget);

      // Confirm logout and trip stoppage
      await tester.tap(find.text('Sair e Parar Viagem'));
      await tester.pumpAndSettle();

      // Dialog is gone and redirected to /login
      expect(find.text('Tela Login'), findsOneWidget);
    });

    testWidgets('7. Operador with inactive trip: Tapping Sair logs out directly without warning dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasDevices: true, isTripActive: false));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Tap Sair
      await tester.ensureVisible(find.text('Sair'));
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      // Warning dialog should NOT appear
      expect(find.text('Viagem em Andamento'), findsNothing);

      // Redirects directly to /login
      expect(find.text('Tela Login'), findsOneWidget);
    });
  });
}
