import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:nutriguard1/services/rota_service.dart';
import 'package:nutriguard1/widgets/selo_sinal_sensor.dart';

void main() {
  group('SinalSensor', () {
    final agora = DateTime(2026, 11, 28, 15, 0, 0);

    test('conectado com leitura recente, desconectado após 20 s', () {
      expect(SinalSensor.conectado(agora.subtract(const Duration(seconds: 5)), agora: agora), isTrue);
      expect(SinalSensor.conectado(agora.subtract(const Duration(seconds: 25)), agora: agora), isFalse);
      expect(SinalSensor.conectado(null, agora: agora), isFalse);
    });

    test('descrições', () {
      expect(SinalSensor.descricao(agora.subtract(const Duration(seconds: 3)), agora: agora),
          'Sensor conectado · leitura há 3 s');
      expect(SinalSensor.descricao(agora.subtract(const Duration(minutes: 12)), agora: agora),
          'Sensor desconectado · última leitura há 12 min');
      expect(SinalSensor.descricao(null, agora: agora), 'Sensor nunca enviou dados');
    });
  });

  group('RotaService', () {
    const sp = LatLng(-23.5505, -46.6333);
    const campinas = LatLng(-22.9056, -47.0626);

    tearDown(() => RotaService.instancia.clienteTeste = null);

    test('usa a rota do OSRM (pelas ruas) e guarda em cache', () async {
      var chamadas = 0;
      RotaService.instancia.clienteTeste = MockClient((req) async {
        chamadas++;
        expect(req.url.host, 'router.project-osrm.org');
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 93900,
                'duration': 4560,
                'geometry': {
                  'coordinates': [
                    [-46.6333, -23.5505],
                    [-46.9, -23.2],
                    [-47.0626, -22.9056],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final rota = await RotaService.instancia.calcular(sp, campinas);
      expect(rota.pelasRuas, isTrue);
      expect(rota.pontos, hasLength(3));
      expect(rota.distanciaKm, closeTo(93.9, 0.01));
      expect(rota.duracaoMin, closeTo(76, 0.01));
      await RotaService.instancia.calcular(sp, campinas);
      expect(chamadas, 1);
      expect(RotaService.instancia.emCache(sp, campinas), isNotNull);
    });

    test('serviço fora do ar: linha reta, sem cache', () async {
      const a = LatLng(-23.0, -46.0);
      const b = LatLng(-23.1, -46.1);
      RotaService.instancia.clienteTeste = MockClient((_) async => http.Response('erro', 503));
      final rota = await RotaService.instancia.calcular(a, b);
      expect(rota.pelasRuas, isFalse);
      expect(rota.pontos, [a, b]);
      expect(RotaService.instancia.emCache(a, b), isNull);
    });
  });
}
