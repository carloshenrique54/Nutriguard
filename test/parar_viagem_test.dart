import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutriguard1/screens/acoes/parar_viagem_screen.dart';
import 'package:nutriguard1/services/trip_service.dart';

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

  Widget createPararViagemTestApp({
    String operatorId = 'op-999',
    ValueChanged<bool?>? onResult,
  }) {
    return MaterialApp(
      routes: {
        '/': (context) => Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    final res = await Navigator.push<bool>(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => PararViagemScreen(
                          initialOperatorId: operatorId,
                        ),
                      ),
                    );
                    onResult?.call(res);
                  },
                  child: const Text('Abrir Parar Viagem'),
                ),
              ),
            ),
      },
    );
  }

  group('PararViagemScreen Layout & Widget Tests', () {
    testWidgets('1. Renders Parar Viajem with header, badge, cards and action button', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createPararViagemTestApp());
      await tester.tap(find.text('Abrir Parar Viagem'));
      await tester.pumpAndSettle();

      // Header e badge
      expect(find.text('Parar Viajem'), findsWidgets);
      expect(find.text('Operador'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);

      // Card 1: Motivo
      expect(find.text('Motivo'), findsOneWidget);
      expect(find.text('Descreva o motivo'), findsOneWidget);
      expect(find.text('Anexar arquivos'), findsOneWidget);
      expect(find.text('Selecionar arquivos'), findsOneWidget);
      expect(find.text('Foto1.png, Foto2.png'), findsOneWidget);

      // Card 2: Local de parada
      expect(find.text('Local de parada'), findsOneWidget);
      expect(find.text('Nome da rua'), findsOneWidget);
      expect(find.text('Bairro'), findsOneWidget);
      expect(find.text('Cidade'), findsOneWidget);
      expect(find.text('CEP (Opcional)'), findsOneWidget);

      // Botão de parada
      expect(find.widgetWithText(ElevatedButton, 'Parar Viajem'), findsOneWidget);
    });

    testWidgets('2. Validates empty Motivo field', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createPararViagemTestApp());
      await tester.tap(find.text('Abrir Parar Viagem'));
      await tester.pumpAndSettle();

      final stopButton = find.widgetWithText(ElevatedButton, 'Parar Viajem');
      await tester.tap(stopButton);
      await tester.pumpAndSettle();

      expect(find.text('Por favor, descreva o motivo da parada.'), findsOneWidget);
    });

    testWidgets('3. Validates empty Rua field', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createPararViagemTestApp());
      await tester.tap(find.text('Abrir Parar Viagem'));
      await tester.pumpAndSettle();

      // Preenche motivo
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Entrega finalizada');
      await tester.pumpAndSettle();

      final stopButton = find.widgetWithText(ElevatedButton, 'Parar Viajem');
      await tester.tap(stopButton);
      await tester.pumpAndSettle();

      expect(find.text('Por favor, informe o nome da rua.'), findsOneWidget);
    });

    testWidgets('4. Validates empty Cidade field', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createPararViagemTestApp());
      await tester.tap(find.text('Abrir Parar Viagem'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Entrega finalizada');
      await tester.enterText(textFields.at(1), 'Av. Brasil, 500');
      await tester.enterText(textFields.at(2), 'Jardins');
      // Deixa cidade vazia
      await tester.pumpAndSettle();

      final stopButton = find.widgetWithText(ElevatedButton, 'Parar Viajem');
      await tester.tap(stopButton);
      await tester.pumpAndSettle();

      expect(find.text('Por favor, informe a cidade do local de parada.'), findsOneWidget);
    });

    testWidgets('5. Successfully submits form, calls TripService and saves stop report', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Inicia viagem primeiro
      final tripService = TripService();
      await tripService.startTrip(
        operatorId: 'op-999',
        deviceId: 'dev-111',
        destination: 'Campinas - SP',
      );
      expect(await tripService.isTripActive('op-999'), isTrue);

      bool? returnResult;
      await tester.pumpWidget(createPararViagemTestApp(
        operatorId: 'op-999',
        onResult: (val) => returnResult = val,
      ));
      await tester.tap(find.text('Abrir Parar Viagem'));
      await tester.pumpAndSettle();

      // Preenche todos os campos
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Parada para descarregamento de vacinas');
      await tester.enterText(textFields.at(1), 'Rua das Flores, 450');
      await tester.enterText(textFields.at(2), 'Centro');
      await tester.enterText(textFields.at(3), 'Campinas');
      await tester.enterText(textFields.at(4), '13010-000');
      await tester.pumpAndSettle();

      // Submete parada
      final stopButton = find.widgetWithText(ElevatedButton, 'Parar Viajem');
      await tester.tap(stopButton);
      await tester.pumpAndSettle();

      // Verifica feedback e retorno com sucesso
      expect(find.text('Viagem finalizada com sucesso!'), findsOneWidget);
      expect(returnResult, isTrue);
      expect(find.text('Abrir Parar Viagem'), findsOneWidget);

      // Verifica persistência no TripService
      expect(await tripService.isTripActive('op-999'), isFalse);
      final report = await tripService.getLastStopReport('op-999');
      expect(report, isNotNull);
      expect(report!.motivo, equals('Parada para descarregamento de vacinas'));
      expect(report.rua, equals('Rua das Flores, 450'));
      expect(report.bairro, equals('Centro'));
      expect(report.cidade, equals('Campinas'));
      expect(report.cep, equals('13010-000'));
      expect(report.anexos, containsAll(['Foto1.png', 'Foto2.png']));
    });

    testWidgets('6. Voltar button navigates back without completing stop', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? returnResult;
      await tester.pumpWidget(createPararViagemTestApp(
        onResult: (val) => returnResult = val,
      ));
      await tester.tap(find.text('Abrir Parar Viagem'));
      await tester.pumpAndSettle();

      expect(find.text('Parar Viajem'), findsWidgets);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Abrir Parar Viagem'), findsOneWidget);
      expect(returnResult, isNull);
    });
  });
}
