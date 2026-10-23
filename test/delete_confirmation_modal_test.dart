import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/widgets/confirmation_dialog.dart';
import 'package:nutriguard1/screens/listagens/listar_operadores_screen.dart';
import 'package:nutriguard1/screens/listagens/listar_frotas_screen.dart';
import 'package:nutriguard1/screens/listagens/listar_dispositivos_screen.dart';
import 'package:nutriguard1/screens/perfil/perfil_screen.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  final testUser = UsuarioModel(
    id: 'user-01',
    nome: 'Carlos Operador',
    cpf: '123.456.789-00',
    cargo: 'operador',
    email: 'carlos@nutriguard.com',
    telefone: '(11) 98888-7777',
    createdAt: DateTime.now(),
  );

  final testFrota = FrotaModel(
    id: 'frota-01',
    nome: 'Frota Frigorífica SP',
    idGerente: 'ger-01',
    createdAt: DateTime.now(),
  );

  final testDevice = DispositivoModel(
    id: 'dev-01',
    idFrota: 'frota-01',
    nomeDispositivo: 'Caminhão Refrigerado A',
    placaVeiculo: 'BRA-2E19',
    modeloVeiculo: 'Volvo FH 540',
  );

  group('Delete Confirmation Modal & Buttons Tests', () {
    testWidgets('1. showDeleteConfirmationModal renders all details and Cancel returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteConfirmationModal(
                    context: context,
                    title: 'Excluir Item de Teste',
                    itemName: 'Caminhão 01',
                    itemDetail: 'Placa: ABC-1234',
                    itemIcon: Icons.directions_car,
                  );
                },
                child: const Text('Abrir Confirmação'),
              ),
            ),
          ),
        ),
      );

      // Open modal
      await tester.tap(find.text('Abrir Confirmação'));
      await tester.pumpAndSettle();

      // Check modal components
      expect(find.text('Excluir Item de Teste'), findsOneWidget);
      expect(find.text('Tem certeza que deseja apagar?'), findsOneWidget);
      expect(find.text('Caminhão 01'), findsOneWidget);
      expect(find.text('Placa: ABC-1234'), findsOneWidget);
      expect(find.text('Esta ação não pode ser desfeita.'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Sim, apagar'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Excluir Item de Teste'), findsNothing);
    });

    testWidgets('2. showDeleteConfirmationModal returns true when confirming', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteConfirmationModal(
                    context: context,
                    title: 'Excluir Frota',
                    itemName: 'Frota Sul',
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Tap Confirm
      await tester.tap(find.text('Sim, apagar'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Excluir Frota'), findsNothing);
    });

    testWidgets('3. ColabCard delete button triggers onDelete callback', (tester) async {
      bool deleteTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColabCard(
              user: testUser,
              infoLabel: 'Veículo Associado',
              infoValue: 'Caminhão 01',
              onDelete: () {
                deleteTriggered = true;
              },
              onTap: () {},
            ),
          ),
        ),
      );

      final deleteIcon = find.byIcon(Icons.delete_outline);
      expect(deleteIcon, findsOneWidget);

      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(deleteTriggered, isTrue);
    });

    testWidgets('4. FleetCard delete button triggers onDelete callback', (tester) async {
      bool deleteTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FleetCard(
              fleet: testFrota,
              gerenteName: 'Gerente Mario',
              deviceCount: 3,
              onDelete: () {
                deleteTriggered = true;
              },
              onTap: () {},
            ),
          ),
        ),
      );

      final deleteIcon = find.byIcon(Icons.delete_outline);
      expect(deleteIcon, findsOneWidget);

      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(deleteTriggered, isTrue);
    });

    testWidgets('5. DeviceCard now includes delete button and triggers onDelete callback', (tester) async {
      bool deleteTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: testDevice,
              operatorName: 'Carlos Operador',
              frotaName: 'Frota Frigorífica SP',
              onDelete: () {
                deleteTriggered = true;
              },
              onTap: () {},
            ),
          ),
        ),
      );

      final deleteIcon = find.byIcon(Icons.delete_outline);
      expect(deleteIcon, findsOneWidget);

      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(deleteTriggered, isTrue);
    });

    testWidgets('6. PerfilScreen displays Excluir funcionário button for non-owner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PerfilScreen(
            role: UserRole.adm,
            usuario: testUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Excluir funcionário'), findsOneWidget);
      expect(find.text('Voltar para a listagem'), findsOneWidget);

      // Tap 'Excluir funcionário' -> opens confirmation modal
      await tester.tap(find.text('Excluir funcionário'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir Funcionário'), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Carlos Operador')), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Sim, apagar'), findsOneWidget);
    });
  });
}
