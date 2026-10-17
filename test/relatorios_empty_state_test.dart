import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/screens/relatorios/relatorios_screen.dart';
import 'package:nutriguard1/services/admin_context_service.dart';
import 'package:nutriguard1/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRelatoriosSupabaseService extends SupabaseService {
  final String role;
  final List<FrotaModel> frotas;
  final List<DispositivoModel> dispositivos;
  final List<MedicaoModel> medicoes;
  final List<OcorrenciaModel> ocorrencias;

  MockRelatoriosSupabaseService({
    required this.role,
    this.frotas = const [],
    this.dispositivos = const [],
    this.medicoes = const [],
    this.ocorrencias = const [],
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
      nome: 'Usuário Teste',
      cpf: '123.456.789-00',
      cargo: role,
      email: 'teste@nutriguard.com',
      telefone: '(11) 99999-9999',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<FrotaModel>> getFrotas() async => frotas;

  @override
  Future<List<FrotaModel>> getFrotasByGerente(String gerenteId) async => frotas;

  @override
  Future<List<FrotaModel>> getFrotasByOperador(String opId) async => frotas;

  @override
  Future<List<DispositivoModel>> getDispositivos() async => dispositivos;

  @override
  Future<List<DispositivoModel>> getDispositivosByFrota(String frotaId) async =>
      dispositivos.where((d) => d.idFrota == frotaId).toList();

  @override
  Future<List<DispositivoModel>> getDispositivosByOperador(String opId) async => dispositivos;

  @override
  Future<List<MedicaoModel>> getMedicoesFiltro(
    List<String> devIds,
    DateTime inicio,
    DateTime fim,
  ) async =>
      medicoes;

  @override
  Future<List<OcorrenciaModel>> getOcorrenciasFiltro(
    List<String> devIds,
    DateTime inicio,
    DateTime fim,
  ) async =>
      ocorrencias;
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

  group('RelatoriosScreen Stylized Empty States Tests', () {
    testWidgets('1. Admin with no fleet selected displays stylized empty state with header and preview features', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockService = MockRelatoriosSupabaseService(
        role: 'admin',
        frotas: [
          FrotaModel(id: 'frota-1', nome: 'Frota Alfa'),
        ],
        dispositivos: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RelatoriosScreen(
            isVehicleContext: false,
            supabaseService: mockService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header is rendered
      expect(find.text('Relatório — Frota'), findsOneWidget);
      expect(find.text('ADM'), findsOneWidget);

      // Pill Badge
      expect(find.text('SELEÇÃO NECESSÁRIA'), findsOneWidget);

      // Title & Subtitle
      expect(find.text('Nenhuma frota selecionada'), findsOneWidget);

      // Feature highlights
      expect(find.text('Gráficos de temperatura e histórico térmico'), findsOneWidget);
      expect(find.text('Índices de conformidade e controle de rota'), findsOneWidget);
      expect(find.text('Exportação de relatórios auditáveis em PDF'), findsOneWidget);

      // Action button
      expect(find.text('Selecionar Frota'), findsOneWidget);
    });

    testWidgets('2. Manager with no assigned fleets displays stylized manager empty state', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockService = MockRelatoriosSupabaseService(
        role: 'gerente',
        frotas: [],
        dispositivos: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RelatoriosScreen(
            isVehicleContext: false,
            supabaseService: mockService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header is rendered
      expect(find.text('Relatório — Frota'), findsOneWidget);
      expect(find.text('GERENTE'), findsOneWidget);

      // Manager empty state badge & title
      expect(find.text('NENHUMA FROTA ATRIBUÍDA'), findsOneWidget);
      expect(find.text('Você não possui frotas atribuídas'), findsOneWidget);
      expect(find.text('Atualizar dados'), findsOneWidget);
    });

    testWidgets('3. Selected fleet with zero records in period displays stylized empty cards for charts, trips, and banner', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testFleet = FrotaModel(id: 'frota-1', nome: 'Frota Beta');
      AdminContextService().setFrota(testFleet);

      final mockService = MockRelatoriosSupabaseService(
        role: 'admin',
        frotas: [testFleet],
        dispositivos: [
          DispositivoModel(id: 'dev-1', nomeDispositivo: 'Caminhão 01', idFrota: 'frota-1'),
        ],
        medicoes: [],
        ocorrencias: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RelatoriosScreen(
            isVehicleContext: false,
            supabaseService: mockService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top Header
      expect(find.text('Relatório — Frota'), findsOneWidget);

      // Empty Period Banner
      expect(find.textContaining('Nenhum dado registrado no período'), findsOneWidget);

      // Metrics Grid with 0s styled
      expect(find.text('Viagens no período'), findsWidgets);
      expect(find.text('0'), findsWidgets);
      expect(find.text('0h 0m'), findsOneWidget);
      expect(find.text('0.0%'), findsOneWidget);

      // Chart 1 Stylized Empty State
      expect(find.text('SEM MEDIÇÕES'), findsOneWidget);
      expect(find.text('Sem medições de temperatura'), findsOneWidget);

      // Chart 2 Stylized Empty State
      expect(find.text('CONFORME'), findsOneWidget);
      expect(find.text('Nenhum alerta registrado'), findsOneWidget);

      // Trips Empty State
      expect(find.text('Nenhuma viagem realizada'), findsOneWidget);

      // Export Button
      expect(find.text('Exportar PDF'), findsOneWidget);
    });
  });
}
