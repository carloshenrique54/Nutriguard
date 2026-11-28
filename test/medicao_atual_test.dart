import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/utils/medicao_atual.dart';

void main() {
  test('leitura falha do DHT22 não apaga temperatura e umidade', () {
    final t0 = DateTime(2026, 11, 28, 19, 6, 26);
    final cronologicas = [
      MedicaoModel(id: 'a', temperatura: 2, umidade: 55, portaAberta: false, bateria: 85, registradoEm: t0),
      MedicaoModel(
        id: 'b',
        temperatura: null,
        umidade: null,
        portaAberta: true,
        bateria: 85,
        registradoEm: t0.add(const Duration(seconds: 6)),
      ),
    ];
    final atual = MedicaoAtual.combinar(cronologicas)!;
    expect(atual.id, 'b');
    expect(atual.registradoEm, t0.add(const Duration(seconds: 6)));
    expect(atual.temperatura, 2);
    expect(atual.umidade, 55);
    expect(atual.portaAberta, isTrue);
  });

  test('sem leituras', () {
    expect(MedicaoAtual.combinar([]), isNull);
  });
}
