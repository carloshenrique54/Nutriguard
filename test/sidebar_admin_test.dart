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

    Widget createTestWidget({
      String currentRoute = '/listar-frotas',
      bool? hasFleets,
      bool? hasDevices,
    }) {
      return MaterialApp(
        initialRoute: currentRoute,
        routes: {
          currentRoute: (context) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => CustomEndDrawer.showMenu(
                      ctx,
                      userRoleOverride: 'admin',
                      hasFleetsOverride: hasFleets,
                      hasDevicesOverride: hasDevices,
                    ),
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

      // Dashboards category and option were removed
      expect(find.text('Dashboards'), findsNothing);
      expect(find.text('Dashboard da frota'), findsNothing);

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

      // Dashboard option was removed from lateral menu
      expect(find.text('Dashboard da frota'), findsNothing);

      // Fleet options are enabled
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

      // Dashboard option was removed from lateral menu
      expect(find.text('Dashboard do veículo'), findsNothing);

      // Vehicle options and GPS are enabled
      expect(find.text('Alertas do veículo'), findsOneWidget);
      expect(find.text('Histórico do veículo'), findsOneWidget);
      expect(find.text('Relatório do veículo'), findsOneWidget);
      expect(find.text('GPS — Veículo'), findsOneWidget);
      expect(find.text('Indisponível'), findsNothing);
    });

    testWidgets('4. No Fleets Registered in System: Context items, Frotas (Seleção), and Listar dispositivos are locked', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(hasFleets: false));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Empty fleet banner
      expect(find.text('Nenhuma frota cadastrada'), findsOneWidget);
      expect(find.text('Cadastre uma frota para habilitar as opções do sistema.'), findsOneWidget);

      // Context items locked with Requer frota
      expect(find.text('Requer frota'), findsWidgets);

      // Frotas (Seleção) is disabled with 'Sem frotas'
      await tester.scrollUntilVisible(find.text('Frotas (Seleção)'), 50);
      expect(find.text('Frotas (Seleção)'), findsOneWidget);
      expect(find.text('Sem frotas'), findsOneWidget);

      // Listar dispositivos is disabled
      await tester.scrollUntilVisible(find.text('Listar dispositivos'), 50);
      expect(find.text('Listar dispositivos'), findsOneWidget);

      // Tapping disabled Frotas (Seleção) shows feedback SnackBar
      await tester.tap(find.text('Frotas (Seleção)'));
      await tester.pump();
      expect(find.text('Nenhuma frota cadastrada no sistema.'), findsOneWidget);

      // Management creation options and Profile remain enabled
      expect(find.text('Criar frota'), findsOneWidget);
      expect(find.text('Cadastrar dispositivo'), findsOneWidget);
      expect(find.text('Listar operadores'), findsOneWidget);
      expect(find.text('Listar gerentes'), findsOneWidget);
      expect(find.text('Cadastrar funcionário'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
    });

    testWidgets('5. Fleet Selected but 0 Devices: Device-dependent fleet options and Listar dispositivos are locked', (tester) async {
      adminContext.setFrota(testFrota);
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(currentRoute: '/dashboard-frota', hasFleets: true, hasDevices: false));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Empty devices banner
      expect(find.text('Nenhum dispositivo cadastrado'), findsOneWidget);
      expect(find.text('Esta frota não possui dispositivos cadastrados. As opções dependentes estão indisponíveis.'), findsOneWidget);

      // Fleet contextual options are locked with Requer dispositivo
      expect(find.text('Requer dispositivo'), findsWidgets);

      // Tapping disabled fleet option shows message
      await tester.tap(find.text('Veículos da frota'));
      await tester.pump();
      expect(find.text('Esta frota não possui nenhum dispositivo cadastrado.'), findsOneWidget);

      // Listar dispositivos is disabled with 'Sem dispositivos'
      await tester.scrollUntilVisible(find.text('Listar dispositivos'), 50);
      expect(find.text('Listar dispositivos'), findsOneWidget);
      expect(find.text('Sem dispositivos'), findsOneWidget);
    });
  });
}
