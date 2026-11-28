import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/services/supabase_service.dart';
import 'package:nutriguard1/utils/alerta_formatacao.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AlertaFormatacao', () {
    test('códigos do banco viram títulos legíveis', () {
      expect(AlertaFormatacao.titulo('vibracao_excessiva'), 'Vibração excessiva');
      expect(AlertaFormatacao.titulo('temperatura_alta'), 'Temperatura acima do limite');
      expect(AlertaFormatacao.titulo('temperatura_baixa'), 'Temperatura abaixo do limite');
      expect(AlertaFormatacao.titulo('porta_aberta'), 'Porta do baú aberta');
      expect(AlertaFormatacao.titulo('Vibração Excessiva'), 'Vibração excessiva');
      expect(AlertaFormatacao.titulo('sensor_offline'), 'Sensor offline');
      expect(AlertaFormatacao.titulo(null), 'Alerta registrado');
    });

    test('detalhe com valor, unidade e limite', () {
      final o = OcorrenciaModel(id: '1', tipo: 'vibracao_excessiva', valorRegistrado: 8.05, limiteConfigurado: 6);
      expect(AlertaFormatacao.detalhe(o), '8,1 m/s² · limite 6 m/s²');
      final t = OcorrenciaModel(id: '2', tipo: 'temperatura_alta', valorRegistrado: 9.5, limiteConfigurado: 8);
      expect(AlertaFormatacao.detalhe(t), '9,5°C · limite 8°C');
      expect(AlertaFormatacao.detalhe(OcorrenciaModel(id: '3', tipo: 'porta_aberta')), 'Abertura registrada');
    });

    test('veículo pela placa (e não pelo pedaço do id)', () {
      final devs = [DispositivoModel(id: '54db3014-aaaa', placaVeiculo: 'RLD7R83')];
      expect(AlertaFormatacao.veiculo('54db3014-aaaa', devs), 'RLD7R83');
      expect(AlertaFormatacao.veiculo('outro', devs), 'Veículo');
    });

    test('temperatura é crítica; vibração não', () {
      expect(AlertaFormatacao.critico('temperatura_alta'), isTrue);
      expect(AlertaFormatacao.critico('vibracao_excessiva'), isFalse);
    });
  });

  test('erros de regra (CHECK) do banco viram mensagem clara', () {
    const e = PostgrestException(
      message: 'new row for relation "Dispositivos" violates check constraint "chk_temperatura_limites"',
      code: '23514',
    );
    expect(SupabaseService.formatarErro(e), 'A temperatura mínima precisa ser menor que a temperatura máxima.');
  });

  test('status resolvido aceita as duas grafias do banco', () {
    expect(AlertaFormatacao.resolvido('Resolvido'), isTrue);
    expect(AlertaFormatacao.resolvido('resolvida'), isTrue);
    expect(AlertaFormatacao.resolvido('aberta'), isFalse);
    expect(AlertaFormatacao.resolvido(null), isFalse);
    expect(AlertaFormatacao.status('aberta'), 'Pendente');
    expect(AlertaFormatacao.status('resolvida'), 'Resolvido');
  });

  test('faixa formata limites com e sem mínimo', () {
    expect(AlertaFormatacao.faixa(-2, 8, '°C'), '-2 a 8°C');
    expect(AlertaFormatacao.faixa(-18.5, -12, '°C'), '-18,5 a -12°C');
    expect(AlertaFormatacao.faixa(null, 80, '%'), 'até 80%');
    expect(AlertaFormatacao.faixa(10, null, '%'), 'a partir de 10%');
    expect(AlertaFormatacao.faixa(null, null, '%'), '--');
  });
}
