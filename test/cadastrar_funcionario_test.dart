import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutriguard1/screens/cadastros/cadastrar_funcionario_screen.dart';

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
      home: CadastrarFuncionarioScreen(bypassAccessCheck: true),
    );
  }

  group('CadastrarFuncionarioScreen Tests', () {
    testWidgets('1. UI components render with initial labels and fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Header title and ADM badge
      expect(find.text('Cadastrar\nFuncionário'), findsOneWidget);
      expect(find.text('ADM'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);

      // Role selector default is Gerente
      expect(find.text('Tipo de funcionário'), findsOneWidget);
      expect(find.text('Gerente'), findsOneWidget);

      // Form inputs
      expect(find.text('Nome do gerente'), findsOneWidget);
      expect(find.text('CPF do gerente'), findsOneWidget);
      expect(find.text('E-mail do gerente'), findsOneWidget);
      expect(find.text('Telefone do gerente'), findsOneWidget);
      expect(find.text('Senha do gerente'), findsOneWidget);
      expect(find.text('Confirmar senha'), findsOneWidget);

      // Submit button
      expect(find.text('Cadastrar gerente'), findsOneWidget);
    });

    testWidgets('2. Role dropdown changes to Operador and updates labels', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Tap dropdown
      await tester.tap(find.text('Gerente'));
      await tester.pumpAndSettle();

      // Select Operador
      await tester.tap(find.text('Operador').last);
      await tester.pumpAndSettle();

      // Verify labels changed
      expect(find.text('Nome do operador'), findsOneWidget);
      expect(find.text('CPF do operador'), findsOneWidget);
      expect(find.text('Cadastrar operador'), findsOneWidget);
    });

    testWidgets('3. Password obscureText toggles when visibility icon is pressed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Find password visibility icons
      final visibilityIcons = find.byIcon(Icons.visibility_outlined);
      expect(visibilityIcons, findsNWidgets(2)); // Senha and Confirmar Senha

      // Tap first eye icon
      await tester.tap(visibilityIcons.first);
      await tester.pump();

      // Icon should change to visibility_off
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('4. Form validation prevents submission with empty fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Tap Cadastrar button with empty fields
      await tester.tap(find.text('Cadastrar gerente'));
      await tester.pump();

      // Validation SnackBar appears
      expect(find.text('Informe o nome completo do funcionário.'), findsOneWidget);
    });

    testWidgets('5. Form validation detects CPF, email, and password mismatch errors', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Fill name
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Carlos Silva');
      await tester.pump();

      // Submit -> asks for CPF
      await tester.tap(find.text('Cadastrar gerente'));
      await tester.pumpAndSettle();
      expect(find.text('Informe o CPF do funcionário.'), findsOneWidget);

      // Fill incomplete CPF
      await tester.enterText(textFields.at(1), '123456');
      await tester.pump();
      await tester.tap(find.text('Cadastrar gerente'));
      await tester.pumpAndSettle();
      expect(find.text('O CPF deve conter exatamente 11 dígitos.'), findsOneWidget);

      // Fill full CPF
      await tester.enterText(textFields.at(1), '12345678901');
      await tester.pump();

      // Submit -> asks for email
      await tester.tap(find.text('Cadastrar gerente'));
      await tester.pumpAndSettle();
      expect(find.text('Informe o e-mail do funcionário.'), findsOneWidget);

      // Fill invalid email
      await tester.enterText(textFields.at(2), 'carlos-invalido');
      await tester.pump();
      await tester.tap(find.text('Cadastrar gerente'));
      await tester.pumpAndSettle();
      expect(find.text('Informe um e-mail válido.'), findsOneWidget);

      // Fill valid email
      await tester.enterText(textFields.at(2), 'carlos@nutriguard.com');
      await tester.pump();

      // Submit -> asks for phone
      await tester.tap(find.text('Cadastrar gerente'));
      await tester.pumpAndSettle();
      expect(find.text('Informe o telefone de contato.'), findsOneWidget);

      // Fill valid phone
      await tester.enterText(textFields.at(3), '11987654321');
      await tester.pump();

      // Submit -> asks for password
      await tester.tap(find.text('Cadastrar gerente'));
      await tester.pumpAndSettle();
      expect(find.text('Defina uma senha de acesso.'), findsOneWidget);

      // Fill short password
      await tester.enterText(textFields.at(4), '123');
      await tester.pump();
      await tester.tap(find.text('Cadastrar gerente'));
      await tester.pumpAndSettle();
      expect(find.text('A senha deve conter no mínimo 6 caracteres.'), findsOneWidget);

      // Fill password and mismatched confirmation
      await tester.enterText(textFields.at(4), '123456');
      await tester.enterText(textFields.at(5), '654321');
      await tester.pump();
      await tester.tap(find.text('Cadastrar gerente'));
      await tester.pumpAndSettle();
      expect(find.text('A confirmação de senha não confere.'), findsOneWidget);
    });

    testWidgets('6. Operador role displays and validates data de nascimento, numero cnh and validade cnh', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Initially Gerente is selected -> operator specific fields must NOT exist
      expect(find.text('Data de nascimento do operador'), findsNothing);
      expect(find.text('Número da CNH do operador'), findsNothing);
      expect(find.text('Validade da CNH do operador'), findsNothing);

      // Select Operador
      await tester.tap(find.text('Gerente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Operador').last);
      await tester.pumpAndSettle();

      // Operator specific fields must now be visible
      expect(find.text('Data de nascimento do operador'), findsOneWidget);
      expect(find.text('Número da CNH do operador'), findsOneWidget);
      expect(find.text('Validade da CNH do operador'), findsOneWidget);

      // Fill common valid data
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Operador João');
      await tester.enterText(textFields.at(1), '12345678901');
      await tester.enterText(textFields.at(2), 'joao.operador@nutriguard.com');
      await tester.enterText(textFields.at(3), '11987654321');

      // Attempt submit without birthdate
      await tester.tap(find.text('Cadastrar operador'));
      await tester.pumpAndSettle();
      expect(find.text('Informe a data de nascimento do operador.'), findsOneWidget);

      // Fill birthdate (at index 4 because birthdate, cnh, validade are placed after phone)
      await tester.enterText(textFields.at(4), '15/05/1990');
      await tester.pumpAndSettle();

      // Attempt submit without CNH
      await tester.tap(find.text('Cadastrar operador'));
      await tester.pumpAndSettle();
      expect(find.text('Informe o número da CNH do operador.'), findsOneWidget);

      // Fill CNH (at index 5)
      await tester.enterText(textFields.at(5), '12345678901');
      await tester.pumpAndSettle();

      // Attempt submit without CNH validity
      await tester.tap(find.text('Cadastrar operador'));
      await tester.pumpAndSettle();
      expect(find.text('Informe a validade da CNH do operador.'), findsOneWidget);

      // Fill CNH validity (at index 6)
      await tester.enterText(textFields.at(6), '15/05/2030');
      await tester.pumpAndSettle();

      // Attempt submit without password
      await tester.tap(find.text('Cadastrar operador'));
      await tester.pumpAndSettle();
      expect(find.text('Defina uma senha de acesso.'), findsOneWidget);
    });
  });
}
