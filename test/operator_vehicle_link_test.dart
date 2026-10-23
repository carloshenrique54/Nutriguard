import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/screens/listagens/listar_dispositivos_screen.dart';

void main() {
  group('Operador Vehicle Linking Tests', () {
    final testOperador = UsuarioModel(
      id: 'op-uuid-123',
      nome: 'João Operador',
      email: 'joao.op@nutriguard.com',
      cpf: '123.456.789-00',
      cargo: 'operador',
    );

    final linkedDevice = DispositivoModel(
      id: 'dev-999',
      nomeDispositivo: 'Volvo FH 540 Frigo',
      idOperador: 'op-uuid-123',
      placaVeiculo: 'BRA2E19',
      modeloVeiculo: 'Volvo FH 540',
      temperaturaMinima: 2.0,
      temperaturaMaxima: 8.0,
    );

    test('1. DispositivoModel properly maps idOperador from/to JSON', () {
      final json = {
        'id': 'dev-100',
        'nome_dispositivo': 'Caminhão Teste',
        'id_operador': 'op-uuid-123',
        'placa_veiculo': 'ABC-1234',
      };

      final model = DispositivoModel.fromJson(json);
      expect(model.id, 'dev-100');
      expect(model.idOperador, 'op-uuid-123');
      expect(model.nomeDispositivo, 'Caminhão Teste');

      final serialized = model.toJson();
      expect(serialized['id_operador'], 'op-uuid-123');
    });

    test('2. Candidate matching handles exact ID, trimmed ID, and case insensitivity', () {
      final candidateIds = {'op-uuid-123', 'joao.op@nutriguard.com', '12345678900'};

      final devWithTrimmedId = DispositivoModel(id: '1', idOperador: ' op-uuid-123 ');
      final devWithEmail = DispositivoModel(id: '2', idOperador: 'JOAO.OP@NUTRIGUARD.COM');
      final devWithCpf = DispositivoModel(id: '3', idOperador: '123.456.789-00');
      final devOther = DispositivoModel(id: '4', idOperador: 'other-uuid');

      bool matches(DispositivoModel d) {
        if (d.idOperador == null) return false;
        final op = d.idOperador!.trim();
        final opClean = op.replaceAll(RegExp(r'\D'), '');
        return candidateIds.any((cid) {
          if (cid.isEmpty) return false;
          if (cid == op || cid.toLowerCase() == op.toLowerCase()) return true;
          if (opClean.isNotEmpty && cid == opClean) return true;
          return false;
        });
      }

      expect(matches(devWithTrimmedId), isTrue);
      expect(matches(devWithEmail), isTrue);
      expect(matches(devWithCpf), isTrue);
      expect(matches(devOther), isFalse);
    });

    testWidgets('3. DeviceCard correctly shows operator name and vehicle details', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: linkedDevice,
              operatorName: testOperador.nome ?? 'Sem Operador',
              frotaName: 'Frota Teste',
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('Volvo FH 540 Frigo'), findsOneWidget);
      expect(find.text('Operador: João Operador'), findsOneWidget);
      expect(find.textContaining('BRA2E19'), findsOneWidget);
    });

    test('4. Dummy mock device is adopted when operator has no directly linked vehicle', () {
      final allDevs = [
        DispositivoModel(id: 'dev-1', nomeDispositivo: 'ESP32 Teste', idOperador: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
        DispositivoModel(id: 'dev-2', nomeDispositivo: 'Outro Veiculo', idOperador: 'other-id'),
      ];

      final candidateIds = {'giovanni-id', 'gigi@gmail.com', 'giovanni'};

      // 1. Matched direto é vazio
      final matched = allDevs.where((d) => candidateIds.contains(d.idOperador)).toList();
      expect(matched.isEmpty, isTrue);

      // 2. Fallback de adoção encontra o dummy
      final dummyDevs = allDevs.where((d) {
        final op = d.idOperador?.trim().toLowerCase() ?? '';
        return op == 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' ||
               op == 'operador teste' ||
               op.isEmpty;
      }).toList();

      expect(dummyDevs.length, 1);
      expect(dummyDevs.first.id, 'dev-1');
      expect(dummyDevs.first.nomeDispositivo, 'ESP32 Teste');
    });
  });
}
