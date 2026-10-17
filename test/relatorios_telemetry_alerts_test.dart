import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/screens/relatorios/relatorios_screen.dart';
import 'package:nutriguard1/services/admin_context_service.dart';
import 'package:nutriguard1/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRelatoriosPopulatedSupabaseService extends SupabaseService {
  final List<FrotaModel> frotas;
  final List<DispositivoModel> dispositivos;
  final List<MedicaoModel> medicoes;
  final List<OcorrenciaModel> ocorrencias;

  MockRelatoriosPopulatedSupabaseService({
    required this.frotas,
    required this.dispositivos,
    required this.medicoes,
    required this.ocorrencias,
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
      nome: 'Carlos Gerente',
      cpf: '123.456.789-00',
      cargo: 'gerente',
      email: 'carlos@nutriguard.com',
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

  group('RelatoriosScreen Recent Telemetry & Alerts Tests', () {
    testWidgets('Renders Telemetria Recente and Alertas & Ocorrências with active telemetry data', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testFrota = FrotaModel(id: 'frota-01', nome: 'Frota Frigorífica SP');
      final testDev = DispositivoModel(
        id: 'dev-01',
        nomeDispositivo: 'Van Refrigerada 01',
        placaVeiculo: 'BRA2E19',
        idFrota: 'frota-01',
        temperaturaMinima: 2.0,
        temperaturaMaxima: 8.0,
      );

      final now = DateTime.now();
      final mockService = MockRelatoriosPopulatedSupabaseService(
        frotas: [testFrota],
        dispositivos: [testDev],
        medicoes: [
          MedicaoModel(
            id: 'med-1',
            idDispositivo: 'dev-01',
            temperatura: 4.5,
            umidade: 62.0,
            vibracao: 0.18,
            portaAberta: false,
            bateria: 95.0,
            registradoEm: now.subtract(const Duration(minutes: 30)),
          ),
          MedicaoModel(
            id: 'med-2',
            idDispositivo: 'dev-01',
            temperatura: 5.2,
            umidade: 58.0,
            vibracao: 0.22,
            portaAberta: false,
            bateria: 94.0,
            registradoEm: now.subtract(const Duration(minutes: 5)),
          ),
        ],
        ocorrencias: [
          OcorrenciaModel(
            id: 'oco-1',
            idDispositivo: 'dev-01',
            tipo: 'Vibração Excessiva',
            valorRegistrado: 2.4,
            limiteConfigurado: 2.0,
            status: 'Pendente',
            criadoEm: now.subtract(const Duration(minutes: 15)),
          ),
          OcorrenciaModel(
            id: 'oco-2',
            idDispositivo: 'dev-01',
            tipo: 'Temperatura Alta',
            valorRegistrado: 9.1,
            limiteConfigurado: 8.0,
            status: 'Resolvido',
            criadoEm: now.subtract(const Duration(hours: 1)),
          ),
        ],
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

      // Top metrics - fleet uses 'Tempo médio de viagem' instead of 'Tempo na rota atual'
      expect(find.text('Tempo médio de viagem'), findsOneWidget);
      expect(find.text('Tempo na rota atual'), findsNothing);

      // Telemetria Recente section exists
      expect(find.text('Telemetria Recente'), findsOneWidget);
      expect(find.text('Temperatura'), findsWidgets);
      expect(find.text('5.2°C'), findsOneWidget);
      expect(find.text('Umidade'), findsWidgets);
      expect(find.text('58%'), findsOneWidget);
      expect(find.text('Vibração'), findsWidgets);
      expect(find.text('0.22G'), findsOneWidget);
      expect(find.text('Bateria & Porta'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);

      // Alertas & Ocorrências section exists with count badge
      expect(find.text('Alertas & Ocorrências'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // badge in counter
      expect(find.text('Vibração Excessiva'), findsOneWidget);
      expect(find.text('Temperatura Alta'), findsOneWidget);
      expect(find.text('Resolvido'), findsOneWidget);
      expect(find.text('Pendente'), findsOneWidget);
      expect(find.textContaining('Registrado: 2.4G'), findsOneWidget);
      expect(find.textContaining('Limite: 2.0G'), findsOneWidget);
      expect(find.textContaining('Registrado: 9.1°C'), findsOneWidget);

      // Export button is present
      expect(find.text('Exportar PDF'), findsOneWidget);
    });
  });
}
