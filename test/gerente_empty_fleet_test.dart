import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/screens/dashboard/dashboard_frota_screen.dart';
import 'package:nutriguard1/services/admin_context_service.dart';
import 'package:nutriguard1/services/supabase_service.dart';
import 'package:nutriguard1/widgets/custom_bottom_nav_bar.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockGerenteSupabaseService extends SupabaseService {
  final String role;
  final List<FrotaModel> frotas;
  final List<DispositivoModel> dispositivos;

  MockGerenteSupabaseService({
    required this.role,
    this.frotas = const [],
    this.dispositivos = const [],
  });

  @override
  User? get currentUser => const User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );

  @override
  Future<UsuarioModel?> getUsuarioPerfil(String userId) async {
    return UsuarioModel(
      id: userId,
      nome: 'Gerente Teste',
      cpf: '123.456.789-00',
      cargo: role,
      email: 'gerente@teste.com',
      telefone: '(11) 99999-9999',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<FrotaModel>> getFrotas() async => frotas;

  @override
  Future<List<FrotaModel>> getFrotasByGerente(String gerenteId) async => frotas;

  @override
  Future<List<DispositivoModel>> getDispositivos() async => dispositivos;

  @override
  Future<List<DispositivoModel>> getDispositivosByFrota(String frotaId) async =>
      dispositivos.where((d) => d.idFrota == frotaId).toList();

  @override
  Future<List<OcorrenciaModel>> getOcorrenciasFiltro(
    List<String> devIds,
    DateTime inicio,
    DateTime fim,
  ) async =>
      [];
}

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

  setUp(() {
    AdminContextService().clearAll();
  });

  group('Gerente Empty Fleet Dashboard Tests', () {
    testWidgets('1. Manager with no fleets does NOT have bottom menu and shows empty state with actions', (tester) async {
      final mockService = MockGerenteSupabaseService(
        role: 'gerente',
        frotas: [],
        dispositivos: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardFrotaScreen(supabaseService: mockService),
        ),
      );

      // Settle loading and async calls
      await tester.pumpAndSettle();

      // Bottom menu MUST be hidden
      expect(find.byType(CustomBottomNavBar), findsNothing);

      // Empty state text must be visible
      expect(find.text('Nenhuma frota atribuída'), findsOneWidget);
      expect(
        find.text('Você não possui nenhuma frota sob sua responsabilidade. A configuração e associação deve ser realizada pelo Administrador.'),
        findsOneWidget,
      );

      // Header must be present with role badge and user greeting
      expect(find.text('Dashboard — Frota'), findsOneWidget);
      expect(find.text('GERENTE'), findsOneWidget);
      expect(find.text('Olá, Gerente Teste'), findsOneWidget);

      // Action buttons must be present
      expect(find.text('Atualizar'), findsOneWidget);
      expect(find.text('Sair da conta'), findsOneWidget);
    });

    testWidgets('2. Manager WITH fleets assigned DOES show bottom menu', (tester) async {
      final mockService = MockGerenteSupabaseService(
        role: 'gerente',
        frotas: [
          FrotaModel(
            id: 'frota-01',
            nome: 'Frota Alfa',
            idGerente: 'test-user-id',
            createdAt: DateTime.now(),
          ),
        ],
        dispositivos: [
          DispositivoModel(
            id: 'dev-01',
            idFrota: 'frota-01',
            nomeDispositivo: 'Caminhão 01',
            placaVeiculo: 'ABC-1234',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardFrotaScreen(supabaseService: mockService),
        ),
      );

      await tester.pumpAndSettle();

      // Bottom menu MUST be visible when manager has fleets
      expect(find.byType(CustomBottomNavBar), findsOneWidget);
      expect(find.textContaining('Frota Alfa'), findsWidgets);
      expect(find.text('Nenhuma frota atribuída'), findsNothing);
    });

    testWidgets('3. Admin viewing DashboardFrotaScreen always has bottom menu', (tester) async {
      final adminFrota = FrotaModel(
        id: 'frota-01',
        nome: 'Frota Geral',
        idGerente: 'gerente-01',
        createdAt: DateTime.now(),
      );
      AdminContextService().setFrota(adminFrota);

      final mockService = MockGerenteSupabaseService(
        role: 'admin',
        frotas: [adminFrota],
        dispositivos: [
          DispositivoModel(
            id: 'dev-01',
            idFrota: 'frota-01',
            nomeDispositivo: 'Veículo 1',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardFrotaScreen(supabaseService: mockService),
        ),
      );

      await tester.pumpAndSettle();

      // Admin has bottom menu
      expect(find.byType(CustomBottomNavBar), findsOneWidget);
      expect(find.text('ADM'), findsOneWidget);
    });

    testWidgets('4. Fleet with 0 devices displays "Nenhum dispositivo cadastrado"', (tester) async {
      final frotaSemDispositivos = FrotaModel(
        id: 'frota-vazia',
        nome: 'Frota Sem Carros',
        idGerente: 'test-user-id',
        createdAt: DateTime.now(),
      );
      AdminContextService().setFrota(frotaSemDispositivos);

      final mockService = MockGerenteSupabaseService(
        role: 'admin',
        frotas: [frotaSemDispositivos],
        dispositivos: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardFrotaScreen(supabaseService: mockService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nenhum dispositivo cadastrado'), findsOneWidget);
      expect(find.text('Esta frota ainda não possui dispositivos vinculados.'), findsOneWidget);
      expect(find.text('Cadastrar dispositivo'), findsOneWidget);
    });

    testWidgets('5. Manager with a fleet that has 0 devices displays "Nenhum dispositivo cadastrado"', (tester) async {
      final frotaGerente = FrotaModel(
        id: 'frota-gerente-01',
        nome: 'Frota do Gerente',
        idGerente: 'test-user-id',
        createdAt: DateTime.now(),
      );

      final mockService = MockGerenteSupabaseService(
        role: 'gerente',
        frotas: [frotaGerente],
        dispositivos: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardFrotaScreen(supabaseService: mockService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nenhum dispositivo cadastrado'), findsOneWidget);
      expect(find.text('Esta frota ainda não possui dispositivos vinculados.'), findsOneWidget);
      expect(find.text('Atualizar'), findsOneWidget);
    });
  });
}
