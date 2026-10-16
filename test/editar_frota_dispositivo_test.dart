import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutriguard1/screens/cadastros/criar_frota_screen.dart';
import 'package:nutriguard1/screens/cadastros/cadastrar_dispositivo_screen.dart';
import 'package:nutriguard1/screens/listagens/listar_frotas_screen.dart';
import 'package:nutriguard1/screens/listagens/listar_dispositivos_screen.dart';
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

  group('Editar Frota Tests', () {
    testWidgets('1. CriarFrotaScreen in edit mode pre-populates name, manager and vehicles', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final frota = FrotaModel(
        id: 'frota-100',
        nome: 'Frota Sudeste',
        idGerente: 'gerente-1',
      );

      final gerente1 = UsuarioModel(
        id: 'gerente-1',
        nome: 'Carlos Gerente',
        cargo: 'gerente',
      );
      final gerente2 = UsuarioModel(
        id: 'gerente-2',
        nome: 'Ana Gerente Livre',
        cargo: 'gerente',
      );

      final devInFleet = DispositivoModel(
        id: 'dev-1',
        nomeDispositivo: 'Caminhão 01',
        idFrota: 'frota-100',
        idOperador: 'op-1',
        modeloVeiculo: 'Scania R450',
        placaVeiculo: 'ABC-1234',
      );
      final devUnassigned = DispositivoModel(
        id: 'dev-2',
        nomeDispositivo: 'Van 02',
        idFrota: null,
        idOperador: 'op-2',
        modeloVeiculo: 'Sprinter',
        placaVeiculo: 'XYZ-9876',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CriarFrotaScreen(
            bypassAccessCheck: true,
            frotaToEdit: frota,
            initialUsers: [gerente1, gerente2],
            initialFrotas: [frota],
            initialDispositivos: [devInFleet, devUnassigned],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header shows Editar frota
      expect(find.text('Editar frota'), findsOneWidget);

      // Submit button shows Salvar alterações
      expect(find.text('Salvar alterações'), findsOneWidget);

      // Name field contains 'Frota Sudeste'
      expect(find.widgetWithText(TextField, 'Frota Sudeste'), findsOneWidget);

      // Manager dropdown displays Carlos Gerente
      expect(find.text('Carlos Gerente'), findsWidgets);

      // Vehicles count shows 1 (the one pre-selected in this fleet)
      expect(find.text('1 veículos'), findsOneWidget);

      // Both vehicles are listed, with status tags
      expect(find.text('Caminhão 01'), findsOneWidget);
      expect(find.text('Van 02'), findsOneWidget);
      expect(find.textContaining('Nesta frota'), findsOneWidget);
      expect(find.textContaining('Sem frota'), findsOneWidget);

      // Can select Van 02 to add it to this fleet
      await tester.tap(find.text('Van 02'));
      await tester.pump();
      expect(find.text('2 veículos'), findsOneWidget);
    });

    testWidgets('2. FleetCard displays edit button for ADM and fires onEdit', (tester) async {
      bool editTapped = false;
      final frota = FrotaModel(id: 'frota-1', nome: 'Frota Norte', idGerente: 'g-1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FleetCard(
              fleet: frota,
              gerenteName: 'João da Silva',
              deviceCount: 3,
              onEdit: () {
                editTapped = true;
              },
              onDelete: () {},
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      expect(editTapped, isTrue);
    });
  });

  group('Editar Dispositivo Tests', () {
    testWidgets('3. CadastrarDispositivoScreen in edit mode pre-populates all fields and displays Salvar alterações', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dev = DispositivoModel(
        id: 'dev-99',
        nomeDispositivo: 'Sensor Frigorífico 01',
        numeroSerie: 'SN-999-XYZ',
        modeloDispositivo: 'NG-Pro 4G',
        modeloVeiculo: 'Volvo FH 540',
        placaVeiculo: 'BRA2E19',
        idFrota: 'frota-1',
        idOperador: 'op-1',
        temperaturaMinima: -18.0,
        temperaturaMaxima: -10.0,
        umidadeMaxima: 80,
        sensibilidadeVibracao: 50,
        limiteVibracao: 70,
        intervaloDados: 30,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CadastrarDispositivoScreen(
            bypassAccessCheck: true,
            dispositivoToEdit: dev,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header shows Editar Dispositivo
      expect(find.text('Editar\nDispositivo'), findsOneWidget);

      // Submit button shows Salvar alterações
      expect(find.text('Salvar alterações'), findsOneWidget);

      // Pre-filled text inputs
      expect(find.widgetWithText(TextField, 'Sensor Frigorífico 01'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'SN-999-XYZ'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'NG-Pro 4G'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Volvo FH 540'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'BRA2E19'), findsOneWidget);
      expect(find.widgetWithText(TextField, '-18.0'), findsOneWidget);
      expect(find.widgetWithText(TextField, '-10.0'), findsOneWidget);
    });

    testWidgets('4. DeviceCard displays edit button for ADM and fires onEdit', (tester) async {
      bool editTapped = false;
      final dev = DispositivoModel(
        id: 'dev-1',
        nomeDispositivo: 'Veículo 01',
        modeloVeiculo: 'Mercedes Actros',
        placaVeiculo: 'ABC-1234',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: dev,
              operatorName: 'Carlos Motorista',
              frotaName: 'Frota Central',
              onEdit: () {
                editTapped = true;
              },
              onDelete: () {},
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      expect(editTapped, isTrue);
    });
  });
}
