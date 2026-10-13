import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutriguard1/screens/cadastros/cadastrar_dispositivo_screen.dart';
import 'package:nutriguard1/services/supabase_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://tlcsqlemhpxftatpivac.supabase.co',
        publishableKey: 'sb_publishable_RkyrNG8clRlnHWJFvmOEPQ_DIRp4SKV',
      );
    } catch (_) {
      // Já inicializado
    }
  });

  Widget buildTestWidget() {
    return const MaterialApp(
      home: CadastrarDispositivoScreen(bypassAccessCheck: true),
    );
  }

  group('CadastrarDispositivoScreen Formatters Tests', () {
    test('SignedDecimalTextInputFormatter handles signed decimals correctly', () {
      final formatter = SignedDecimalTextInputFormatter();

      TextEditingValue format(String oldText, String newText) {
        return formatter.formatEditUpdate(
          TextEditingValue(text: oldText),
          TextEditingValue(text: newText),
        );
      }

      // Valid values
      expect(format('', '-').text, '-');
      expect(format('-', '-1').text, '-1');
      expect(format('-1', '-18.5').text, '-18.5');
      expect(format('', '2.0').text, '2.0');
      expect(format('', '4,5').text, '4,5');

      // Invalid values (should revert to old text)
      expect(format('', 'abc').text, '');
      expect(format('-18', '-18.5.5').text, '-18');
      expect(format('', '--5').text, '');
    });

    test('PercentageTextInputFormatter constrains between 0 and 100', () {
      final formatter = PercentageTextInputFormatter();

      TextEditingValue format(String oldText, String newText) {
        return formatter.formatEditUpdate(
          TextEditingValue(text: oldText),
          TextEditingValue(text: newText),
        );
      }

      // Valid percentages
      expect(format('', '0').text, '0');
      expect(format('', '50').text, '50');
      expect(format('', '100').text, '100');
      expect(format('', '75.5').text, '75.5');
      expect(format('', '99,9').text, '99,9');

      // Values over 100 or invalid should revert
      expect(format('10', '101').text, '10');
      expect(format('', '150').text, '');
      expect(format('', '-5').text, '');
      expect(format('', 'abc').text, '');
    });

    test('UpperCaseTextFormatter converts text to uppercase', () {
      final formatter = UpperCaseTextFormatter();

      final res = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: 'abc1d23'),
      );
      expect(res.text, 'ABC1D23');
    });
  });

  group('CadastrarDispositivoScreen Widget & Validation Tests', () {
    testWidgets('1. UI components and unit suffixes render properly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Header and titles
      expect(find.text('Cadastrar\nDispositivo'), findsOneWidget);
      expect(find.text('ADM'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);

      // Section titles
      expect(find.text('Dados do dispositivo (Todos obrigatórios)'), findsOneWidget);
      expect(find.text('Vínculo e Veículo (Frota opcional)'), findsOneWidget);
      expect(find.text('Configurações dos sensores (Todos obrigatórios)'), findsOneWidget);
      expect(find.text('Apenas números'), findsOneWidget);

      // Form labels
      expect(find.text('Nome do dispositivo'), findsOneWidget);
      expect(find.text('Número de série'), findsOneWidget);
      expect(find.text('Modelo do dispositivo'), findsOneWidget);
      expect(find.text('Frota vinculada'), findsOneWidget);
      expect(find.text('Operador responsável'), findsOneWidget);
      expect(find.text('(Obrigatório)'), findsOneWidget);
      expect(find.text('(Opcional)'), findsOneWidget);
      expect(find.text('*'), findsWidgets);
      expect(find.text('Modelo do veículo'), findsOneWidget);
      expect(find.text('Placa do veículo'), findsOneWidget);

      // Sensor labels and suffixes
      expect(find.text('Temperatura mínima'), findsOneWidget);
      expect(find.text('Temperatura máxima'), findsOneWidget);
      expect(find.text('Umidade máxima'), findsOneWidget);
      expect(find.text('Sensibilidade do sensor de vibração'), findsOneWidget);
      expect(find.text('Limite de vibração'), findsOneWidget);
      expect(find.text('Intervalo entre coletas de dados'), findsOneWidget);

      // Unit badges: 2x °C, 3x %, 1x s
      expect(find.text('°C'), findsNWidgets(2));
      expect(find.text('%'), findsNWidgets(3));
      expect(find.text('s'), findsOneWidget);

      // Submit button
      expect(find.text('Cadastrar Dispositivo'), findsOneWidget);
    });

    testWidgets('2. Fleet is optional; validation prevents submission when operator is not selected', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Tap submit with empty form and no fleet selected
      final submitBtn = find.text('Cadastrar Dispositivo');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Fleet is optional: should NOT demand fleet, demands operator instead
      expect(find.text('Selecione uma frota para vincular o dispositivo!'), findsNothing);
      expect(find.text('Selecione o operador responsável pelo dispositivo!'), findsOneWidget);
    });

    testWidgets('2b. Validation prevents submission when operator is not selected', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(
        home: CadastrarDispositivoScreen(
          bypassAccessCheck: true,
          initialFrotaId: 'frota-uuid-123',
        ),
      ));
      await tester.pump();

      // Tap submit with fleet selected but no operator selected
      final submitBtn = find.text('Cadastrar Dispositivo');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Should show red SnackBar demanding operator selection
      expect(find.text('Selecione o operador responsável pelo dispositivo!'), findsOneWidget);
    });

    testWidgets('3. Sensor inputs only accept numbers and formatters block letters', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Find Temperatura mínima input and try to enter letters (should be rejected)
      final tempMinField = find.widgetWithText(TextField, 'Ex: 2.0 ou -18.0');
      await tester.ensureVisible(tempMinField);
      await tester.enterText(tempMinField, 'abc');
      await tester.pump();
      final tempMinWidget = tester.widget<TextField>(tempMinField);
      expect(tempMinWidget.controller?.text, '');

      // Entering valid signed decimal is accepted
      await tester.enterText(tempMinField, '-15.5');
      await tester.pump();
      expect(tempMinWidget.controller?.text, '-15.5');

      // Find Umidade máxima input and enter invalid text > 100 or letters (should be rejected)
      final humidadeField = find.widgetWithText(TextField, 'Ex: 75');
      await tester.ensureVisible(humidadeField);
      await tester.enterText(humidadeField, '150');
      await tester.pump();
      final humidadeWidget = tester.widget<TextField>(humidadeField);
      expect(humidadeWidget.controller?.text, '');

      // Entering valid percentage (0-100) is accepted
      await tester.enterText(humidadeField, '80');
      await tester.pump();
      expect(humidadeWidget.controller?.text, '80');

      // Find Intervalo input and enter letters (should be rejected by digitsOnly)
      final intervaloField = find.widgetWithText(TextField, 'Ex: 30');
      await tester.ensureVisible(intervaloField);
      await tester.enterText(intervaloField, 'segundos');
      await tester.pump();
      final intervaloWidget = tester.widget<TextField>(intervaloField);
      expect(intervaloWidget.controller?.text, '');

      // Entering valid digits is accepted
      await tester.enterText(intervaloField, '45');
      await tester.pump();
      expect(intervaloWidget.controller?.text, '45');
    });

    test('4. SupabaseService.formatarErro formats id_frota not-null constraint error', () {
      // Simulate raw PostgrestException from Postgres constraint 23502
      final error = PostgrestException(
        message: 'null value in column "id_frota" of relation "Dispositivos" violates not-null constraint',
        code: '23502',
      );

      final formatted = SupabaseService.formatarErro(error);
      expect(formatted, contains('restrição NOT NULL na coluna id_frota'));

      // Also simulate string exception containing the same message
      final strError = Exception(
        'PostgrestException: null value in column "id_frota" of relation "Dispositivos" violates not-null constraint',
      );
      final formattedStr = SupabaseService.formatarErro(strError);
      expect(formattedStr, contains('restrição NOT NULL na coluna id_frota'));
    });
  });
}
