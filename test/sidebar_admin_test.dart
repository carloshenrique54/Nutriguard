import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/services/admin_context_service.dart';
import 'package:nutriguard1/widgets/custom_end_drawer.dart';

void main() {
  group('CustomEndDrawer ADM Dynamic Sidebar Tests', () {
    final adminContext = AdminContextService();

    final testFrota = FrotaModel(
      id: 'frota-101',
      nome: 'Frota Regional Sul',
      idGerente: 'gerente-1',
      createdAt: DateTime.now(),
    );

    final testDevice = DispositivoModel(
      id: 'dev-202',
      idFrota: 'frota-101',
      nomeDispositivo: 'Van Refrigerada 02',
      placaVeiculo: 'XYZ-9876',
    );

    Widget createTestWidget({String currentRoute = '/listar-frotas'}) {
      return MaterialApp(
        initialRoute: currentRoute,
        routes: {
          currentRoute: (context) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => CustomEndDrawer.showMenu(ctx, userRoleOverride: 'admin'),
                    child: const Text('Open Drawer'),
                  ),
                ),
              ),
        },
      );
    }

    setUp(() {
      adminContext.clearAll();
    });

    testWidgets('1. No Fleet Selected: Context items are disabled and GPS is unavailable', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Context Banner shows no fleet
      expect(find.text('Nenhuma frota selecionada'), findsOneWidget);

      // Dashboards category was removed
      expect(find.text('Dashboards'), findsNothing);

      // Requer frota badge appears on locked items
      expect(find.text('Requer frota'), findsWidgets);

      // GPS is disabled with "Indisponível"
      expect(find.text('Indisponível'), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);

      // Frotas is accessible (scroll to it if offscreen)
      await tester.scrollUntilVisible(find.text('Frotas (Seleção)'), 50);
      expect(find.text('Frotas (Seleção)'), findsOneWidget);

      // Listar dispositivos is accessible in GERENCIAMENTO
      await tester.scrollUntilVisible(find.text('Listar dispositivos'), 50);
      expect(find.text('Listar dispositivos'), findsOneWidget);
    });

    testWidgets('2. Fleet Selected: Fleet options are enabled and GPS remains unavailable', (tester) async {
      adminContext.setFrota(testFrota);

      await tester.pumpWidget(createTestWidget(currentRoute: '/dashboard-frota'));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Banner shows selected fleet
      expect(find.text('FROTA SELECIONADA'), findsOneWidget);
      expect(find.text('Frota Regional Sul'), findsOneWidget);

      // Fleet options are enabled
      expect(find.text('Dashboard da frota'), findsOneWidget);
      expect(find.text('Veículos da frota'), findsOneWidget);
      expect(find.text('Alertas da frota'), findsOneWidget);
      expect(find.text('Histórico da frota'), findsOneWidget);
      expect(find.text('Relatório da frota'), findsOneWidget);

      // GPS remains strictly disabled
      expect(find.text('Indisponível'), findsOneWidget);
      expect(find.text('GPS — Frota'), findsOneWidget);
    });

    testWidgets('3. Vehicle Selected: Vehicle options are enabled and origin fleet link is visible', (tester) async {
      adminContext.setDevice(testDevice, frota: testFrota);

      await tester.pumpWidget(createTestWidget(currentRoute: '/dashboard-veiculo'));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Banner shows selected vehicle and origin fleet
      expect(find.text('VEÍCULO SELECIONADO'), findsOneWidget);
      expect(find.text('XYZ-9876'), findsOneWidget);
      expect(find.text('Frota: Frota Regional Sul'), findsOneWidget);

      // Vehicle options are enabled
      expect(find.text('Dashboard do veículo'), findsOneWidget);
      expect(find.text('Alertas do veículo'), findsOneWidget);
      expect(find.text('Histórico do veículo'), findsOneWidget);
      expect(find.text('Relatório do veículo'), findsOneWidget);

      // GPS remains strictly disabled
      expect(find.text('Indisponível'), findsOneWidget);
      expect(find.text('GPS — Veículo'), findsOneWidget);
    });
  });
}
