import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/utils/resumo_frota.dart';

void main() {
  final a = DispositivoModel(id: 'a', placaVeiculo: 'AAA1A11', umidadeMaxima: 80);
  final b = DispositivoModel(id: 'b', placaVeiculo: 'BBB2B22', umidadeMaxima: 80);
  final c = DispositivoModel(id: 'c', placaVeiculo: 'CCC3C33', umidadeMaxima: 70);
  final t0 = DateTime(2026, 11, 28, 10);

  MedicaoModel med(String id, {num? temp, num? umid, DateTime? quando}) =>
      MedicaoModel(id: 'm$id', idDispositivo: id, temperatura: temp, umidade: umid, registradoEm: quando);

  OcorrenciaModel oc(String id, String tipo, {String status = 'aberta'}) =>
      OcorrenciaModel(id: 'o$id$tipo', idDispositivo: id, tipo: tipo, status: status);

  test('sem leituras: nada é inventado', () {
    final r = ResumoFrota.calcular([a, b], {}, []);
    expect(r.temperaturaMedia, isNull);
    expect(r.umidadeMedia, isNull);
    expect(r.ultimaLeitura, isNull);
    expect(r.normais, 2);
    expect(ResumoFrota.tempoDesde(null), 'Sem leituras');
  });

  test('médias e última leitura vêm das medições reais', () {
    final r = ResumoFrota.calcular([a, b, c], {
      'a': med('a', temp: 4, umid: 60, quando: t0),
      'b': med('b', temp: 6, umid: 90, quando: t0.add(const Duration(minutes: 5))),
      'c': null,
    }, []);
    expect(r.temperaturaMedia, 5);
    expect(r.umidadeMedia, 75);
    expect(r.ultimaLeitura, t0.add(const Duration(minutes: 5)));
    expect(r.umidadeForaLimite, 1); // b: 90% > 80%
    expect(r.limiteUmidadeComum, isNull); // 80 e 70
  });

  test('limite comum quando todos usam o mesmo', () {
    expect(ResumoFrota.calcular([a, b], {}, []).limiteUmidadeComum, 80);
  });

  test('crítico/atenção por veículo, com códigos do banco e sem contar duas vezes', () {
    final r = ResumoFrota.calcular([a, b, c], {}, [
      oc('a', 'temperatura_alta'),
      oc('a', 'porta_aberta'),
      oc('b', 'vibracao_excessiva'),
      oc('c', 'temperatura_baixa', status: 'resolvida'),
    ]);
    expect(r.criticos, 1);
    expect(r.atencao, 1);
    expect(r.normais, 1);
  });

  test('tempoDesde', () {
    final agora = DateTime(2026, 11, 28, 12);
    expect(ResumoFrota.tempoDesde(agora.subtract(const Duration(seconds: 20)), agora: agora), 'agora mesmo');
    expect(ResumoFrota.tempoDesde(agora.subtract(const Duration(minutes: 7)), agora: agora), '7 minuto(s) atrás');
    expect(ResumoFrota.tempoDesde(agora.subtract(const Duration(hours: 3)), agora: agora), '3h atrás');
    expect(ResumoFrota.tempoDesde(agora.subtract(const Duration(days: 2)), agora: agora), '2 dia(s) atrás');
  });
}
