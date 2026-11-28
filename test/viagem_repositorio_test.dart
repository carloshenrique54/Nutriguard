import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/services/trip_service.dart';
import 'package:nutriguard1/services/viagem_repositorio.dart';
import 'package:nutriguard1/utils/alerta_formatacao.dart';
import 'package:nutriguard1/utils/resumo_frota.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ViagemRepositorioLocal repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = ViagemRepositorioLocal();
    TripService.repositorio = repo;
  });

  group('Regras de viagem', () {
    test('operador não abre segunda viagem em outro veículo', () async {
      await repo.iniciar(operadorId: 'op1', dispositivoId: 'v1', destino: 'Campinas');
      expect(
        () => repo.iniciar(operadorId: 'op1', dispositivoId: 'v2', destino: 'Santos'),
        throwsA(isA<ViagemException>()),
      );
    });

    test('veículo em viagem não aceita outro operador', () async {
      await repo.iniciar(operadorId: 'op1', dispositivoId: 'v1', destino: 'Campinas');
      expect(
        () => repo.iniciar(operadorId: 'op2', dispositivoId: 'v1', destino: 'Santos'),
        throwsA(isA<ViagemException>()),
      );
    });

    test('reiniciar no mesmo veículo devolve a viagem aberta', () async {
      final a = await repo.iniciar(operadorId: 'op1', dispositivoId: 'v1', destino: 'Campinas');
      final b = await repo.iniciar(operadorId: 'op1', dispositivoId: 'v1', destino: 'Campinas');
      expect(b.id, a.id);
    });

    test('encerrar grava fim e duração; veículo sai da lista em viagem', () async {
      await repo.iniciar(operadorId: 'op1', dispositivoId: 'v1', destino: 'Campinas');
      await repo.iniciar(operadorId: 'op2', dispositivoId: 'v2', destino: 'Santos');
      expect(await TripService().devicesInTrip(['v1', 'v2', 'v3']), {'v1', 'v2'});

      await TripService().endTrip('op1');
      expect(await TripService().devicesInTrip(['v1', 'v2']), {'v2'});

      final agora = DateTime.now();
      final periodo = await repo.doPeriodo(['v1'], agora.subtract(const Duration(days: 1)), agora);
      expect(periodo, hasLength(1));
      expect(periodo.first.status, ViagemRepositorio.finalizada);
      expect(periodo.first.finalizadoEm, isNotNull);
      expect(periodo.first.duracaoMinutos, 0);
    });

    test('isDeviceInTrip olha o veículo, não o operador', () async {
      await repo.iniciar(operadorId: 'op1', dispositivoId: 'v1', destino: 'Campinas');
      expect(await TripService().isDeviceInTrip('v1'), isTrue);
      expect(await TripService().isDeviceInTrip('v2', operatorId: 'op1'), isFalse);
    });
  });

  group('Avisos de fim de viagem', () {
    final comRelatorio = OcorrenciaModel(id: '1', idDispositivo: 'v1', tipo: 'viagem_finalizada', valorRegistrado: 85);
    final semRelatorio = OcorrenciaModel(id: '2', idDispositivo: 'v1', tipo: 'viagem_encerrada_sem_relatorio', valorRegistrado: 40);

    test('títulos e detalhes diferentes para com e sem relatório', () {
      expect(AlertaFormatacao.titulo(comRelatorio.tipo), 'Viagem finalizada com relatório');
      expect(AlertaFormatacao.titulo(semRelatorio.tipo), 'Viagem encerrada sem relatório');
      expect(AlertaFormatacao.detalhe(comRelatorio), 'Duração 1h 25min · relatório de parada enviado');
      expect(AlertaFormatacao.detalhe(semRelatorio), 'Duração 40min · sem formulário de parada');
      expect(AlertaFormatacao.iconeViagem(comRelatorio.tipo), isNot(AlertaFormatacao.iconeViagem(semRelatorio.tipo)));
      expect(AlertaFormatacao.critico(semRelatorio.tipo), isFalse);
    });

    test('avisos de viagem não mudam a situação do veículo no painel', () {
      final d = DispositivoModel(id: 'v1');
      final r = ResumoFrota.calcular([d], {}, [comRelatorio, semRelatorio]);
      expect(r.normais, 1);
      expect(r.atencao, 0);
      expect(r.criticos, 0);
    });
  });
}
