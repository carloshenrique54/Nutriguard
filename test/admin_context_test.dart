import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/services/admin_context_service.dart';

void main() {
  group('AdminContextService Unit Tests', () {
    final service = AdminContextService();

    final testFrotaA = FrotaModel(
      id: 'frota-1',
      nome: 'Frota Alfa',
      idGerente: 'gerente-1',
      createdAt: DateTime.now(),
    );

    final testFrotaB = FrotaModel(
      id: 'frota-2',
      nome: 'Frota Beta',
      idGerente: 'gerente-2',
      createdAt: DateTime.now(),
    );

    final testDeviceA = DispositivoModel(
      id: 'dev-1',
      idFrota: 'frota-1',
      nomeDispositivo: 'Caminhão 01',
      placaVeiculo: 'ABC-1234',
      modeloVeiculo: 'Scania',
    );

    setUp(() {
      service.clearAll();
    });

    test('Initial state is completely empty', () {
      expect(service.hasFrota, isFalse);
      expect(service.hasDevice, isFalse);
      expect(service.selectedFrota, isNull);
      expect(service.selectedDevice, isNull);
      expect(service.currentFrotaName, isNull);
      expect(service.currentDeviceName, isNull);
    });

    test('Selecting a fleet sets frota and notifies listeners', () {
      var notified = false;
      void listener() => notified = true;
      service.addListener(listener);

      service.setFrota(testFrotaA);

      expect(service.hasFrota, isTrue);
      expect(service.selectedFrota?.id, equals('frota-1'));
      expect(service.currentFrotaName, equals('Frota Alfa'));
      expect(service.hasDevice, isFalse);
      expect(notified, isTrue);

      service.removeListener(listener);
    });

    test('Selecting a device with its fleet sets both and maintains association', () {
      service.setDevice(testDeviceA, frota: testFrotaA);

      expect(service.hasFrota, isTrue);
      expect(service.hasDevice, isTrue);
      expect(service.selectedFrota?.id, equals('frota-1'));
      expect(service.selectedDevice?.id, equals('dev-1'));
      expect(service.currentFrotaName, equals('Frota Alfa'));
      expect(service.currentDeviceName, equals('ABC-1234'));
    });

    test('clearVehicle keeps fleet selected but resets device', () {
      service.setDevice(testDeviceA, frota: testFrotaA);
      expect(service.hasDevice, isTrue);

      service.clearVehicle();

      expect(service.hasFrota, isTrue);
      expect(service.hasDevice, isFalse);
      expect(service.selectedFrota?.id, equals('frota-1'));
      expect(service.selectedDevice, isNull);
    });

    test('Switching to a different fleet clears the previously selected vehicle', () {
      service.setDevice(testDeviceA, frota: testFrotaA);
      expect(service.hasDevice, isTrue);

      service.setFrota(testFrotaB);

      expect(service.hasFrota, isTrue);
      expect(service.selectedFrota?.id, equals('frota-2'));
      expect(service.hasDevice, isFalse);
      expect(service.selectedDevice, isNull);
    });

    test('clearAll clears both fleet and vehicle', () {
      service.setDevice(testDeviceA, frota: testFrotaA);
      expect(service.hasFrota, isTrue);
      expect(service.hasDevice, isTrue);

      service.clearAll();

      expect(service.hasFrota, isFalse);
      expect(service.hasDevice, isFalse);
      expect(service.selectedFrota, isNull);
      expect(service.selectedDevice, isNull);
    });
  });
}
