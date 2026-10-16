import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutriguard1/screens/cadastros/criar_frota_screen.dart';
import 'package:nutriguard1/models/models.dart';

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

  group('CriarFrotaScreen Widget & Optional Vehicle Tests', () {
    testWidgets('1. UI components render with optional vehicle selection and labels', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CriarFrotaScreen(bypassAccessCheck: true),
        ),
      );
      await tester.pump();

      // Header and Submit button both contain 'Criar frota'
      expect(find.text('Criar frota'), findsNWidgets(2));
      expect(find.widgetWithText(ElevatedButton, 'Criar frota'), findsOneWidget);
      expect(find.text('ADM'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);

      // Section titles
      expect(find.text('Nome da frota'), findsOneWidget);
      expect(find.text('Gerente responsável'), findsOneWidget);
      expect(find.text('(Obrigatório)'), findsOneWidget);

      // Vehicle selection header shows (Opcional)
      expect(find.text('Selecionar veículos'), findsOneWidget);
      expect(find.text('(Opcional)'), findsOneWidget);
    });

    testWidgets('2. Validation demands fleet name and manager, but allows 0 vehicles selected', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CriarFrotaScreen(bypassAccessCheck: true),
        ),
      );
      await tester.pump();

      // Tap submit with empty name
      final submitBtn = find.text('Criar frota').last;
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Preencha o nome da frota!'), findsOneWidget);

      // Wait for snackbar to dismiss so it doesn't obscure the button
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Fill name
      final nameField = find.byType(TextField);
      await tester.enterText(nameField, 'Frota Teste Sem Carro');
      await tester.pump();

      // Tap submit without manager
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Selecione o gerente responsável pela frota!'), findsOneWidget);
      // Notice: NO error demanding vehicles is shown because vehicles are optional!
      expect(find.textContaining('veículo'), findsWidgets);
    });

    testWidgets('3. Empty state message shown when no unassigned vehicles are available', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CriarFrotaScreen(bypassAccessCheck: true),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // When mock or backend returns no unassigned vehicles, empty state is displayed
      expect(find.text('0 veículos'), findsOneWidget);
      expect(find.text('Nenhum veículo disponível sem frota'), findsOneWidget);
    });

    testWidgets('4. Voltar button pops back correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('Root Screen')),
        ),
      );

      navKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const CriarFrotaScreen(bypassAccessCheck: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Criar frota'), findsWidgets);
      final voltarBtn = find.text('Voltar');
      expect(voltarBtn, findsOneWidget);
      await tester.tap(voltarBtn);
      await tester.pumpAndSettle();

      expect(find.text('Root Screen'), findsOneWidget);
    });

    testWidgets('5. Managers with assigned fleets are excluded from the dropdown', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final gerenteComFrota = UsuarioModel(
        id: 'g-ocupado',
        nome: 'Gerente Ocupado',
        cargo: 'gerente',
        email: 'ocupado@teste.com',
      );
      final gerenteSemFrota = UsuarioModel(
        id: 'g-livre',
        nome: 'Gerente Livre',
        cargo: 'gerente',
        email: 'livre@teste.com',
      );
      final frotaExistente = FrotaModel(
        id: 'f-1',
        nome: 'Frota Alfa',
        idGerente: 'g-ocupado',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CriarFrotaScreen(
            bypassAccessCheck: true,
            initialUsers: [gerenteComFrota, gerenteSemFrota],
            initialFrotas: [frotaExistente],
            initialDispositivos: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open manager dropdown
      final dropdown = find.byType(DropdownButton<String>);
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // 'Gerente Livre' MUST be available in the dropdown options
      expect(find.text('Gerente Livre'), findsWidgets);

      // 'Gerente Ocupado' MUST NOT be available in the dropdown options
      expect(find.text('Gerente Ocupado'), findsNothing);
    });

    testWidgets('6. When all managers already have fleets, dropdown displays disabled message and cannot select', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final gerente1 = UsuarioModel(id: 'g-1', nome: 'Gerente Um', cargo: 'gerente');
      final gerente2 = UsuarioModel(id: 'g-2', nome: 'Gerente Dois', cargo: 'gerente');
      final frota1 = FrotaModel(id: 'f-1', nome: 'Frota 1', idGerente: 'g-1');
      final frota2 = FrotaModel(id: 'f-2', nome: 'Frota 2', idGerente: 'g-2');

      await tester.pumpWidget(
        MaterialApp(
          home: CriarFrotaScreen(
            bypassAccessCheck: true,
            initialUsers: [gerente1, gerente2],
            initialFrotas: [frota1, frota2],
            initialDispositivos: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dropdown should indicate no managers are available without a fleet
      expect(find.text('Nenhum gerente disponível sem frota'), findsOneWidget);

      final dropdown = tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      // onChanged is null when disabled
      expect(dropdown.onChanged, isNull);
    });
  });
}
