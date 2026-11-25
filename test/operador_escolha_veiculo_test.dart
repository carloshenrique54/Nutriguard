import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/services/trip_service.dart';
import 'package:nutriguard1/services/veiculo_operador_service.dart';
import 'package:nutriguard1/widgets/seletor_veiculo.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Operador com mais de um veículo escolhe qual vai controlar.
void main() {
  final v1 = DispositivoModel(id: 'v1', placaVeiculo: 'AAA1A11', modeloVeiculo: 'Ford Cargo 816');
  final v2 = DispositivoModel(id: 'v2', placaVeiculo: 'BBB2B22', modeloVeiculo: 'Volvo VM 270');
  final service = VeiculoOperadorService();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('VeiculoOperadorService.resolver', () {
    test('um único veículo é escolhido automaticamente', () async {
      expect((await service.resolver('op', [v1]))?.id, 'v1');
    });

    test('vários veículos e nenhuma escolha: pede para escolher (null)', () async {
      expect(await service.resolver('op', [v1, v2]), isNull);
    });

    test('a escolha salva é lembrada', () async {
      await service.salvarEscolha('op', 'v2');
      expect((await service.resolver('op', [v1, v2]))?.id, 'v2');
    });

    test('escolha salva de veículo que não é mais dele é ignorada', () async {
      await service.salvarEscolha('op', 'v-removido');
      expect(await service.resolver('op', [v1, v2]), isNull);
    });

    test('a viagem em andamento manda: usa o veículo da viagem', () async {
      await service.salvarEscolha('op', 'v1');
      await TripService().startTrip(operatorId: 'op', deviceId: 'v2', destination: 'Santos');
      expect((await service.resolver('op', [v1, v2]))?.id, 'v2');
    });

    test('escolhas de operadores diferentes não se misturam', () async {
      await service.salvarEscolha('op-a', 'v1');
      await service.salvarEscolha('op-b', 'v2');
      expect((await service.resolver('op-a', [v1, v2]))?.id, 'v1');
      expect((await service.resolver('op-b', [v1, v2]))?.id, 'v2');
    });
  });

  testWidgets('Seletor lista os veículos e devolve o escolhido', (tester) async {
    DispositivoModel? escolhido;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => escolhido = await mostrarSeletorVeiculo(context, [v1, v2], atualId: 'v1'),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Qual veículo você vai controlar?'), findsOneWidget);
    expect(find.text('AAA1A11'), findsOneWidget);
    expect(find.text('BBB2B22'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // veículo atual marcado

    await tester.tap(find.byKey(const Key('seletor_veiculo_v2')));
    await tester.pumpAndSettle();
    expect(escolhido?.id, 'v2');
  });
}
