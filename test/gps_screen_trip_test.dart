import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutriguard1/screens/gps/gps_screen.dart';
import 'package:nutriguard1/services/trip_service.dart';
import 'package:nutriguard1/services/supabase_service.dart';
import 'package:nutriguard1/models/models.dart';

class MockGpsSupabaseService extends SupabaseService {
  final DispositivoModel device;

  MockGpsSupabaseService(this.device);

  @override
  User? get currentUser => const User(
        id: 'op-lucas-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );

  @override
  Future<UsuarioModel?> getUsuarioPerfil(String userId) async {
    return UsuarioModel(
      id: userId,
      nome: 'Lucas Mendes',
      cpf: '123.456.789-00',
      cargo: 'operador',
      email: 'operador.lucas@nutriguard.com',
      telefone: '(11) 98888-8888',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<DispositivoModel>> getDispositivosByOperador(String operadorId) async {
    return [device];
  }

  @override
  Future<List<DispositivoModel>> getDispositivos() async {
    return [device];
  }

  @override
  Future<List<MedicaoModel>> getMedicoesFiltro(List<String> ids, DateTime inicio, DateTime fim) async {
    return [
      MedicaoModel(
        id: 'med-1',
        idDispositivo: device.id,
        temperatura: 4.5,
        bateria: 85,
        portaAberta: false,
        latitude: -23.5505,
        longitude: -46.6333,
        registradoEm: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ];
  }

  @override
  Future<MedicaoModel?> getLatestMedicao(String dispositivoId) async {
    return MedicaoModel(
      id: 'med-1',
      idDispositivo: dispositivoId,
      temperatura: 4.5,
      bateria: 85,
      portaAberta: false,
      latitude: -23.5505,
      longitude: -46.6333,
      registradoEm: DateTime.now().subtract(const Duration(hours: 5)),
    );
  }
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  final dummyDevice = DispositivoModel(
    id: 'dev-teste-123',
    nomeDispositivo: 'Sensor IoT TermoGuard #01',
    numeroSerie: 'TG-SUL-4019',
    modeloDispositivo: 'NutriSensor Pro v2',
    modeloVeiculo: 'Mercedes Sprinter 416 CDI',
    placaVeiculo: 'BRA-2E19',
    idOperador: 'op-lucas-123',
  );

  Widget createGpsTestApp({DispositivoModel? device}) {
    final dev = device ?? dummyDevice;
    return MaterialApp(
      routes: {
        '/': (context) => GpsScreen(
              initialDevice: dev,
              supabaseService: MockGpsSupabaseService(dev),
            ),
        '/parar-viagem': (context) => const Scaffold(body: Text('Tela Parar Viagem')),
        '/dashboard-veiculo': (context) => const Scaffold(body: Text('Dashboard Veiculo')),
        '/relatorios-veiculo': (context) => const Scaffold(body: Text('Relatorios Veiculo')),
      },
    );
  }

  group('TripService getActiveTripByDevice Tests', () {
    test('1. Looks up active trip by device ID', () async {
      final tripService = TripService();
      await tripService.startTrip(
        operatorId: 'op-lucas-123',
        deviceId: 'dev-teste-123',
        destination: 'Centro de Distribuição São Paulo',
        vehiclePlate: 'BRA-2E19',
        vehicleModel: 'Mercedes Sprinter',
        destinationLatitude: -23.5505,
        destinationLongitude: -46.6333,
      );

      final trip = await tripService.getActiveTripByDevice('dev-teste-123');
      expect(trip, isNotNull);
      expect(trip?.destination, 'Centro de Distribuição São Paulo');
      expect(trip?.vehiclePlate, 'BRA-2E19');
      expect(trip?.destinationLatitude, -23.5505);

      final inTrip = await tripService.isDeviceInTrip('dev-teste-123');
      expect(inTrip, isTrue);

      await tripService.endTrip('op-lucas-123');
      final tripAfter = await tripService.getActiveTripByDevice('dev-teste-123');
      expect(tripAfter, isNull);
    });
  });

  group('GpsScreen Trip Status Tests', () {
    testWidgets('2. Displays Em trânsito and destination when vehicle is in active trip (even with telemetry older than 2 hours)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tripService = TripService();
      await tripService.startTrip(
        operatorId: 'op-lucas-123',
        deviceId: 'dev-teste-123',
        destination: 'São Paulo - Centro',
        vehiclePlate: 'BRA-2E19',
        vehicleModel: 'Mercedes Sprinter',
        destinationLatitude: -23.5800,
        destinationLongitude: -46.6800,
      );

      await tester.pumpWidget(createGpsTestApp(device: dummyDevice));
      await tester.pumpAndSettle();

      // O badge de status deve exibir "Em trânsito", e não "Parado / Offline"
      expect(find.text('Em trânsito'), findsWidgets);
      expect(find.text('Parado / Offline'), findsNothing);

      // Deve mostrar a placa do veículo
      expect(find.text('BRA-2E19'), findsWidgets);

      // O destino da viagem deve ser exibido
      expect(find.text('Destino: São Paulo - Centro'), findsOneWidget);

      // O botão "Parar Viagem" deve estar visível para o operador em viagem
      expect(find.text('Parar Viagem'), findsOneWidget);
    });

    testWidgets('3. Displays Parado / Offline when vehicle is NOT in trip and telemetry is old', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createGpsTestApp(device: dummyDevice));
      await tester.pumpAndSettle();

      // Sem viagem ativa e com telemetria de 5h atrás, exibe "Parado / Offline"
      expect(find.text('Parado / Offline'), findsOneWidget);
      expect(find.text('Em trânsito'), findsNothing);
    });
  });
}
