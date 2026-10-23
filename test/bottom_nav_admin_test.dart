import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/services/admin_context_service.dart';
import 'package:nutriguard1/widgets/custom_bottom_nav_bar.dart';

void main() {
  group('CustomBottomNavBar ADM Disabled Items and Gray Symbols Tests', () {
    final adminContext = AdminContextService();

    final testFrota = FrotaModel(
      id: 'frota-01',
      nome: 'Frota Express',
      idGerente: 'gerente-01',
      createdAt: DateTime.now(),
    );

    final testDevice = DispositivoModel(
      id: 'dev-01',
      idFrota: 'frota-01',
      nomeDispositivo: 'Caminhão 01',
      placaVeiculo: 'ABC-1234',
    );

    Widget createTestWidget({int? selectedIndex}) {
      return MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CustomBottomNavBar(
            selectedIndex: selectedIndex,
            userRoleOverride: 'admin',
          ),
          body: const Center(child: Text('Content')),
        ),
      );
    }

    setUp(() {
      adminContext.clearAll();
    });

    testWidgets('1. No Fleet Selected: All bottom bar items are gray and non-clickable', (tester) async {
      await tester.pumpWidget(createTestWidget(selectedIndex: null));
      await tester.pumpAndSettle();

      // Verify all 5 labels are rendered
      expect(find.text('Alertas'), findsOneWidget);
      expect(find.text('Relatórios'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Histórico'), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);

      // Verify that the text styles are gray (Color(0xFF757575))
      final alertaText = tester.widget<Text>(find.text('Alertas'));
      expect(alertaText.style?.color, equals(const Color(0xFF757575)));

      final relatorioText = tester.widget<Text>(find.text('Relatórios'));
      expect(relatorioText.style?.color, equals(const Color(0xFF757575)));

      final dashboardText = tester.widget<Text>(find.text('Dashboard'));
      expect(dashboardText.style?.color, equals(const Color(0xFF757575)));

      final historicoText = tester.widget<Text>(find.text('Histórico'));
      expect(historicoText.style?.color, equals(const Color(0xFF757575)));

      final gpsText = tester.widget<Text>(find.text('GPS'));
      expect(gpsText.style?.color, equals(const Color(0xFF757575)));

      // Verify that icons are gray (Color(0xFF757575))
      final icons = tester.widgetList<Icon>(find.byType(Icon));
      for (final icon in icons) {
        expect(icon.color, equals(const Color(0xFF757575)));
      }

      // Verify that tapping does not navigate or throw
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget); // still on same screen
    });

    testWidgets('2. Fleet Selected: Fleet items are enabled, but GPS remains gray and non-clickable', (tester) async {
      adminContext.setFrota(testFrota);

      await tester.pumpWidget(createTestWidget(selectedIndex: 2));
      await tester.pumpAndSettle();

      // GPS must still be gray (Color(0xFF757575))
      final gpsText = tester.widget<Text>(find.text('GPS'));
      expect(gpsText.style?.color, equals(const Color(0xFF757575)));

      final gpsIcon = tester.widget<Icon>(find.byIcon(Icons.location_on_outlined));
      expect(gpsIcon.color, equals(const Color(0xFF757575)));

      // Enabled items must be black (Colors.black87)
      final alertaText = tester.widget<Text>(find.text('Alertas'));
      expect(alertaText.style?.color, equals(Colors.black87));

      final relatorioText = tester.widget<Text>(find.text('Relatórios'));
      expect(relatorioText.style?.color, equals(Colors.black87));

      final historicoText = tester.widget<Text>(find.text('Histórico'));
      expect(historicoText.style?.color, equals(Colors.black87));
    });

    testWidgets('3. Vehicle Selected: Vehicle items and GPS are enabled for ADM in vehicle context', (tester) async {
      adminContext.setDevice(testDevice, frota: testFrota);

      await tester.pumpWidget(createTestWidget(selectedIndex: 2));
      await tester.pumpAndSettle();

      // GPS is enabled in vehicle context
      final gpsText = tester.widget<Text>(find.text('GPS'));
      expect(gpsText.style?.color, equals(Colors.black87));

      final gpsIcon = tester.widget<Icon>(find.byIcon(Icons.location_on_outlined));
      expect(gpsIcon.color, equals(Colors.black87));

      // Enabled items are black (Colors.black87)
      final alertaText = tester.widget<Text>(find.text('Alertas'));
      expect(alertaText.style?.color, equals(Colors.black87));
    });

    testWidgets('4. Gerente in fleet context (isVehicleContext: false): GPS remains gray and non-clickable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CustomBottomNavBar(
              selectedIndex: 2,
              userRoleOverride: 'gerente',
              isVehicleContext: false,
            ),
            body: Center(child: Text('Gerente Fleet Dashboard')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // GPS must be gray (Color(0xFF757575)) because fleet dashboard cannot take to GPS
      final gpsText = tester.widget<Text>(find.text('GPS'));
      expect(gpsText.style?.color, equals(const Color(0xFF757575)));

      final gpsIcon = tester.widget<Icon>(find.byIcon(Icons.location_on_outlined));
      expect(gpsIcon.color, equals(const Color(0xFF757575)));

      // Tap GPS does nothing
      await tester.tap(find.text('GPS'));
      await tester.pumpAndSettle();
      expect(find.text('Gerente Fleet Dashboard'), findsOneWidget);
    });

    testWidgets('5. GPS is disabled when hasDevicesOverride: false even in vehicle context', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CustomBottomNavBar(
              selectedIndex: 2,
              userRoleOverride: 'operador',
              isVehicleContext: true,
              hasDevicesOverride: false,
            ),
            body: Center(child: Text('Operador No Device')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gpsText = tester.widget<Text>(find.text('GPS'));
      expect(gpsText.style?.color, equals(const Color(0xFF757575)));

      final gpsIcon = tester.widget<Icon>(find.byIcon(Icons.location_on_outlined));
      expect(gpsIcon.color, equals(const Color(0xFF757575)));
    });
  });
}
