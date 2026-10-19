import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/screens/perfil/perfil_screen.dart';
import 'package:nutriguard1/screens/listagens/listar_operadores_screen.dart';
import 'package:nutriguard1/widgets/custom_bottom_nav_bar.dart';

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

  final testOperador = UsuarioModel(
    id: 'op-01',
    nome: 'Carlos Operador',
    email: 'carlos.op@nutriguard.com',
    telefone: '(11) 98888-7777',
    cpf: '123.456.789-00',
    cargo: 'operador',
    dataNascimento: DateTime(1995, 5, 20),
    numeroCnh: '12345678900',
    validadeCnh: DateTime(2028, 5, 20),
    createdAt: DateTime.now(),
  );

  final testGerente = UsuarioModel(
    id: 'ger-01',
    nome: 'Mariana Gerente',
    email: 'mariana.ger@nutriguard.com',
    telefone: '(11) 97777-6666',
    cpf: '987.654.321-99',
    cargo: 'gerente',
    dataNascimento: DateTime(1988, 11, 15),
    numeroCnh: '99887766554',
    validadeCnh: DateTime(2027, 10, 10),
    createdAt: DateTime.now(),
  );

  group('ColabCard Tests', () {
    testWidgets('1. ColabCard displays employee info and Ver mais button triggering onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColabCard(
              user: testOperador,
              infoLabel: 'Veículo Associado',
              infoValue: 'Caminhão 01',
              onDelete: () {},
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Carlos Operador'), findsOneWidget);
      expect(find.text('CPF: 123.456.789-00'), findsOneWidget);
      expect(find.text('Veículo Associado'), findsOneWidget);
      expect(find.text('Caminhão 01'), findsOneWidget);
      expect(find.text('Ver mais'), findsOneWidget);

      await tester.tap(find.text('Ver mais'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('Employee Profile (PerfilScreen) Tests', () {
    testWidgets('2. Operador profile displays birthday, CNH and back button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PerfilScreen(usuario: testOperador),
        ),
      );
      await tester.pumpAndSettle();

      // Header shows employee profile title
      expect(find.text('Perfil do Funcionário'), findsOneWidget);

      // Card details
      expect(find.text('Carlos Operador'), findsOneWidget);
      expect(find.text('carlos.op@nutriguard.com'), findsOneWidget);
      expect(find.text('CPF: 123.456.789-00'), findsOneWidget);

      // Birthday is shown exclusively for operador
      expect(find.text('Aniversário: 20/05/1995'), findsOneWidget);
      expect(find.text('CNH: 12345678900'), findsOneWidget);
      expect(find.text('Validade CNH: 20/05/2028'), findsOneWidget);

      // Back button to return to employee list
      expect(find.text('Voltar para a listagem'), findsOneWidget);

      // Operador displays 'Dispositivo responsável >' instead of 'Minhas frotas >'
      expect(find.text('Dispositivo responsável >'), findsOneWidget);
      expect(find.text('Minhas frotas >'), findsNothing);
    });

    testWidgets('3. Gerente profile does NOT display birthday or CNH and shows Frota responsável', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PerfilScreen(usuario: testGerente),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Perfil do Funcionário'), findsOneWidget);
      expect(find.text('Mariana Gerente'), findsOneWidget);
      expect(find.text('mariana.ger@nutriguard.com'), findsOneWidget);
      expect(find.text('CPF: 987.654.321-99'), findsOneWidget);

      // BIRTHDAY MUST NOT BE DISPLAYED FOR GERENTE
      expect(find.textContaining('Aniversário'), findsNothing);
      expect(find.textContaining('15/11/1988'), findsNothing);
      expect(find.textContaining('CNH'), findsNothing);

      // Back button
      expect(find.text('Voltar para a listagem'), findsOneWidget);

      // Gerente displays 'Frota responsável >' instead of 'Dispositivo responsável >'
      expect(find.text('Frota responsável >'), findsOneWidget);
      expect(find.text('Minhas frotas >'), findsNothing);
      expect(find.text('Dispositivo responsável >'), findsNothing);
    });

    testWidgets('4. Profile received via ModalRoute arguments renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/perfil', arguments: testOperador),
                    child: const Text('Go'),
                  ),
                ),
            '/perfil': (context) => const PerfilScreen(),
          },
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('Perfil do Funcionário'), findsOneWidget);
      expect(find.text('Carlos Operador'), findsOneWidget);
      expect(find.text('Aniversário: 20/05/1995'), findsOneWidget);
    });

    testWidgets('5. When viewer is ADM, header badge displays ADM instead of Operador', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PerfilScreen(role: UserRole.adm, usuario: testOperador),
        ),
      );
      await tester.pumpAndSettle();

      // Top title and role badge
      expect(find.text('Perfil do Funcionário'), findsOneWidget);
      expect(find.text('ADM'), findsOneWidget);
      expect(find.text('OPERADOR'), findsOneWidget); // Cargo chip in card
    });

    testWidgets('6. Profile card has organized document sections and no fake scrollbar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PerfilScreen(role: UserRole.adm, usuario: testOperador),
        ),
      );
      await tester.pumpAndSettle();

      // Clean sections inside card
      expect(find.text('Documento'), findsOneWidget);
      expect(find.text('Nascimento'), findsOneWidget);
      expect(find.text('Habilitação'), findsOneWidget);
      expect(find.text('Vencimento'), findsOneWidget);

      // Verify contact
      expect(find.text('(11) 98888-7777'), findsOneWidget);
    });

    testWidgets('7. PerfilScreen does not render bottom navigation menu as it is not usable on profile screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PerfilScreen(role: UserRole.adm, usuario: testOperador),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomBottomNavBar), findsNothing);
    });

    testWidgets('8. Admin profile displays Gestão da Operação and quick shortcuts instead of Minhas frotas', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testAdmin = UsuarioModel(
        id: 'admin-123',
        nome: 'Carlos Admin',
        email: 'admin@nutriguard.com',
        cargo: 'admin',
        cpf: '123.456.789-00',
        telefone: '(11) 98765-4321',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PerfilScreen(usuario: testAdmin),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gestão da Operação >'), findsOneWidget);
      expect(find.text('Minhas frotas >'), findsNothing);
      expect(find.text('FROTAS ATIVAS'), findsOneWidget);
      expect(find.text('VEÍCULOS & SENSORES IoT'), findsOneWidget);
      expect(find.text('EQUIPE DA OPERAÇÃO'), findsOneWidget);
      expect(find.text('ATALHOS DE CADASTRO'), findsOneWidget);
      expect(find.text('+ Frota'), findsOneWidget);
      expect(find.text('+ Veículo'), findsOneWidget);
      expect(find.text('+ Equipe'), findsOneWidget);
    });
  });
}
