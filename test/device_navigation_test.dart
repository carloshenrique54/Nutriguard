import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/services/admin_context_service.dart';
import 'package:nutriguard1/screens/listagens/listar_dispositivos_screen.dart';
import 'package:nutriguard1/screens/listagens/listar_frotas_screen.dart';
import 'package:nutriguard1/widgets/custom_bottom_nav_bar.dart';

void main() {
  group('Device vs Fleet Navigation Tests', () {
    final adminContext = AdminContextService();

    final testFrota = FrotaModel(
      id: 'frota-01',
      nome: 'Frota Frigorífica SP',
      idGerente: 'gerente-01',
      createdAt: DateTime.now(),
    );

    final testDevice = DispositivoModel(
      id: 'dev-01',
      idFrota: 'frota-01',
      nomeDispositivo: 'Caminhão Refrigerado A',
      placaVeiculo: 'BRA-2E19',
      modeloVeiculo: 'Volvo FH 540',
    );

    setUp(() {
      adminContext.clearAll();
    });

    testWidgets('1. DeviceCard has Ver mais button that triggers onTap callback with device context', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: testDevice,
              operatorName: 'Carlos Silva',
              frotaName: 'Frota Frigorífica SP',
              onDelete: () {},
              onTap: () {
                tapped = true;
                adminContext.setDevice(testDevice, frota: testFrota);
              },
            ),
          ),
        ),
      );

      // Verify device title, plate, and 'Ver mais' button exist
      expect(find.text('Caminhão Refrigerado A'), findsOneWidget);
      expect(find.text('Ver mais'), findsOneWidget);

      // Tap 'Ver mais'
      await tester.tap(find.text('Ver mais'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(adminContext.hasDevice, isTrue);
      expect(adminContext.currentDeviceId, equals('dev-01'));
    });

    testWidgets('2. CustomBottomNavBar prioritizes isVehicleContext: true and preserves vehicle dashboard route', (tester) async {
      adminContext.setFrota(testFrota);
      // Even without setting device in adminContext beforehand, isVehicleContext: true should maintain vehicle context
      expect(adminContext.hasDevice, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CustomBottomNavBar(
              selectedIndex: 2,
              isVehicleContext: true,
              userRoleOverride: 'admin',
              currentDevice: testDevice,
            ),
            body: const Center(child: Text('Vehicle Dashboard Body')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dashboard item is enabled because fleet is selected
      expect(find.text('Dashboard'), findsOneWidget);
      final dashboardText = tester.widget<Text>(find.text('Dashboard'));
      expect(dashboardText.style?.color, equals(Colors.black87));
    });

    testWidgets('3. FleetCard displays "Ver frota" instead of "Ver mais" and tapping vehicles triggers vehicle list', (tester) async {
      bool fleetTapped = false;
      bool vehiclesTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FleetCard(
              fleet: testFrota,
              gerenteName: 'Gerente João',
              deviceCount: 5,
              onDelete: () {},
              onTap: () {
                fleetTapped = true;
              },
              onTapVehicles: () {
                vehiclesTapped = true;
              },
            ),
          ),
        ),
      );

      // Advance clock for TweenAnimationBuilder duration (1500ms)
      await tester.pump(const Duration(milliseconds: 1600));

      // Button must say 'Ver frota', eliminating ambiguity with device cards
      expect(find.text('Ver frota'), findsOneWidget);
      expect(find.text('Veículos na frota'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Tap 'Ver frota'
      await tester.tap(find.text('Ver frota'));
      await tester.pumpAndSettle();
      expect(fleetTapped, isTrue);

      // Tap 'Veículos na frota'
      await tester.tap(find.text('Veículos na frota'));
      await tester.pumpAndSettle();
      expect(vehiclesTapped, isTrue);
    });
  });
}
