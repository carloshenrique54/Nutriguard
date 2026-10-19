import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/services/trip_service.dart';
import 'package:nutriguard1/screens/acoes/iniciar_viagem_screen.dart';
import 'package:nutriguard1/widgets/custom_end_drawer.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://tlcsqlemhpxftatpivac.supabase.co',
        publishableKey: 'sb_publishable_RkyrNG8clRlnHWJFvmOEPQ_DIRp4SKV',
      );
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  final testOperador = UsuarioModel(
    id: 'op-123',
    nome: 'João Operador',
    email: 'joao.op@nutriguard.com',
    cargo: 'operador',
  );

  final testDevice = DispositivoModel(
    id: 'dev-123',
    nomeDispositivo: 'IoT Carga',
    placaVeiculo: 'BRA2E19',
    modeloVeiculo: 'Mercedes Sprinter',
    temperaturaMinima: 2.0,
    temperaturaMaxima: 8.0,
  );

  group('TripService Unit Tests', () {
    test('Initial state: operator has no active trip', () async {
      final tripService = TripService();
      final active = await tripService.isTripActive('op-123');
      expect(active, isFalse);

      final tripInfo = await tripService.getActiveTrip('op-123');
      expect(tripInfo, isNull);
    });

    test('Start trip: records active trip with destination and device', () async {
      final tripService = TripService();
      await tripService.startTrip(
        operatorId: 'op-123',
        deviceId: 'dev-456',
        destination: 'Centro de Distribuição - SP',
        vehiclePlate: 'ABC-1234',
        vehicleModel: 'Mercedes Sprinter',
      );

      final active = await tripService.isTripActive('op-123');
      expect(active, isTrue);

      final tripInfo = await tripService.getActiveTrip('op-123');
      expect(tripInfo, isNotNull);
      expect(tripInfo!.destination, equals('Centro de Distribuição - SP'));
      expect(tripInfo.deviceId, equals('dev-456'));
      expect(tripInfo.vehiclePlate, equals('ABC-1234'));
      expect(tripInfo.vehicleModel, equals('Mercedes Sprinter'));
      expect(tripInfo.formattedDuration, contains('0h'));
    });

    test('End trip: marks trip as inactive', () async {
      final tripService = TripService();
      await tripService.startTrip(
        operatorId: 'op-123',
        deviceId: 'dev-456',
        destination: 'Campinas - SP',
      );
      expect(await tripService.isTripActive('op-123'), isTrue);

      await tripService.endTrip('op-123');
      expect(await tripService.isTripActive('op-123'), isFalse);
      expect(await tripService.getActiveTrip('op-123'), isNull);
    });

    test('End trip with report: marks trip as inactive and persists stop report', () async {
      final tripService = TripService();
      await tripService.startTrip(
        operatorId: 'op-123',
        deviceId: 'dev-456',
        destination: 'Santos - SP',
      );
      expect(await tripService.isTripActive('op-123'), isTrue);

      await tripService.endTripWithReport(
        operatorId: 'op-123',
        motivo: 'Entrega finalizada com sucesso no cliente',
        rua: 'Rua do Comércio, 120',
        bairro: 'Centro',
        cidade: 'Santos',
        cep: '11010-000',
        anexos: ['Foto1.png', 'Foto2.png', 'Assinatura.png'],
      );

      expect(await tripService.isTripActive('op-123'), isFalse);
      expect(await tripService.getActiveTrip('op-123'), isNull);

      final report = await tripService.getLastStopReport('op-123');
      expect(report, isNotNull);
      expect(report!.motivo, equals('Entrega finalizada com sucesso no cliente'));
      expect(report.rua, equals('Rua do Comércio, 120'));
      expect(report.bairro, equals('Centro'));
      expect(report.cidade, equals('Santos'));
      expect(report.cep, equals('11010-000'));
      expect(report.anexos, containsAll(['Foto1.png', 'Foto2.png', 'Assinatura.png']));
    });
  });

  group('IniciarViagemScreen Widget Tests', () {
    Widget buildTestApp({DispositivoModel? device}) {
      return MaterialApp(
        routes: {
          '/': (context) => IniciarViagemScreen(
                initialUser: testOperador,
                initialDevice: device ?? testDevice,
              ),
          '/dashboard-veiculo': (context) => const Scaffold(body: Text('Tela Dashboard Veiculo')),
        },
      );
    }

    testWidgets('1. Renders Iniciar Viagem Screen with title, vehicle card and action button', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Iniciar Viagem'), findsWidgets);
      expect(find.text('Mercedes Sprinter'), findsOneWidget);
      expect(find.text('BRA2E19'), findsOneWidget);
      expect(find.text('Iniciar viagem'), findsOneWidget);
    });

    testWidgets('2. Validates empty destination when attempting to start trip', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final button = find.widgetWithText(ElevatedButton, 'Iniciar viagem');
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Por favor, informe o destino da viagem.'), findsOneWidget);
    });

    testWidgets('3. Validates short destination (< 3 characters)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      await tester.enterText(textFields.first, 'SP');
      await tester.pumpAndSettle();

      final button = find.widgetWithText(ElevatedButton, 'Iniciar viagem');
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('O destino deve ter pelo menos 3 caracteres.'), findsOneWidget);
    });

    testWidgets('4. Starting trip with valid destination persists and navigates', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Centro de Distribuição São Paulo');
      await tester.pumpAndSettle();

      final button = find.widgetWithText(ElevatedButton, 'Iniciar viagem');
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Tela Dashboard Veiculo'), findsOneWidget);
      final active = await TripService().isTripActive('op-123');
      expect(active, isTrue);
    });

    testWidgets('5. Renders route map section and selecting preset chip fills destination', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Verifica elementos do mapa
      expect(find.text('Mapa da Rota'), findsOneWidget);
      expect(find.text('Expandir'), findsOneWidget);
      expect(find.text('Hub Campinas'), findsOneWidget);
      expect(find.text('Porto de Santos'), findsOneWidget);

      // Toca no chip de preset 'Hub Campinas'
      await tester.tap(find.text('Hub Campinas'));
      await tester.pumpAndSettle();

      // Verifica se o TextField foi preenchido
      expect(find.text('Hub Campinas'), findsWidgets);

      // Inicia viagem
      final button = find.widgetWithText(ElevatedButton, 'Iniciar viagem');
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Tela Dashboard Veiculo'), findsOneWidget);
      final tripInfo = await TripService().getActiveTrip('op-123');
      expect(tripInfo, isNotNull);
      expect(tripInfo!.destination, equals('Hub Campinas'));
      expect(tripInfo.destinationLatitude, equals(-22.9099));
      expect(tripInfo.destinationLongitude, equals(-47.0626));
    });
  });

  group('CustomEndDrawer Operator Trip Options Tests', () {
    Widget createDrawerTestWidget({
      required bool isTripActive,
    }) {
      return MaterialApp(
        routes: {
          '/': (context) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => CustomEndDrawer.showMenu(
                      ctx,
                      userRoleOverride: 'operador',
                      hasDevicesOverride: true,
                      isTripActiveOverride: isTripActive,
                    ),
                    child: const Text('Open Menu'),
                  ),
                ),
              ),
          '/iniciar-viagem': (context) => const Scaffold(body: Text('Tela Iniciar Viagem')),
          '/parar-viagem': (context) => const Scaffold(body: Text('Tela Parar Viagem')),
        },
      );
    }

    testWidgets('1. Operator with inactive trip sees Iniciar viagem option', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createDrawerTestWidget(isTripActive: false));
      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar viagem'), findsOneWidget);
      expect(find.text('Parar viagem'), findsNothing);
    });

    testWidgets('2. Operator with active trip sees Parar viagem option', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createDrawerTestWidget(isTripActive: true));
      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Parar viagem'), findsOneWidget);
      expect(find.text('Iniciar viagem'), findsNothing);
    });

    testWidgets('3. Operator tapping Parar viagem navigates to /parar-viagem', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createDrawerTestWidget(isTripActive: true));
      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parar viagem'));
      await tester.pumpAndSettle();

      expect(find.text('Tela Parar Viagem'), findsOneWidget);
    });

    testWidgets('4. Operator navigating to /parar-viagem from drawer and popping returns to previous screen', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createDrawerTestWidget(isTripActive: true));
      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parar viagem'));
      await tester.pumpAndSettle();

      expect(find.text('Tela Parar Viagem'), findsOneWidget);

      // Simulate tapping Voltar / popping /parar-viagem
      Navigator.pop(tester.element(find.text('Tela Parar Viagem')));
      await tester.pumpAndSettle();

      // The original screen that opened the menu (e.g. Dashboard) must still be there
      expect(find.text('Open Menu'), findsOneWidget);
      expect(find.text('Tela Parar Viagem'), findsNothing);
    });
  });
}
