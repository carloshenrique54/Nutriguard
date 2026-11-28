import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Rota pelas ruas entre dois pontos.
class Rota {
  final List<LatLng> pontos;
  final double distanciaKm;
  final double duracaoMin;

  /// `false` quando o serviço de rotas não respondeu e a rota é a linha reta.
  final bool pelasRuas;

  const Rota({required this.pontos, required this.distanciaKm, required this.duracaoMin, required this.pelasRuas});

  factory Rota.linhaReta(LatLng a, LatLng b) => Rota(
        pontos: [a, b],
        distanciaKm: const Distance().as(LengthUnit.Meter, a, b) / 1000,
        duracaoMin: 0,
        pelasRuas: false,
      );
}

/// Calcula rotas pelas ruas com o OSRM (roteador público do OpenStreetMap).
/// Se o serviço estiver fora do ar ou bloqueado pela rede, devolve a linha reta.
class RotaService {
  RotaService._();
  static final RotaService instancia = RotaService._();

  @visibleForTesting
  http.Client? clienteTeste;

  static const _base = 'https://router.project-osrm.org/route/v1/driving';
  static final http.Client _http = http.Client();
  final Map<String, Rota> _cache = {};
  final Map<String, Future<Rota>> _emAndamento = {};

  static String _chave(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)};'
      '${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}';

  /// Rota já calculada (sem consultar a rede), ou `null`.
  Rota? emCache(LatLng a, LatLng b) => _cache[_chave(a, b)];

  Future<Rota> calcular(LatLng a, LatLng b) {
    final chave = _chave(a, b);
    final pronta = _cache[chave];
    if (pronta != null) return Future.value(pronta);
    // Bloco sem retorno: devolver o Future removido faria o whenComplete esperar por ele mesmo.
    return _emAndamento[chave] ??= _buscar(a, b).whenComplete(() {
      _emAndamento.remove(chave);
    });
  }

  Future<Rota> _buscar(LatLng a, LatLng b) async {
    final url = Uri.parse(
      '$_base/${a.longitude},${a.latitude};${b.longitude},${b.latitude}?overview=full&geometries=geojson',
    );
    try {
      final resp = await (clienteTeste ?? _http).get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final corpo = jsonDecode(resp.body) as Map<String, dynamic>;
      final rotas = corpo['routes'] as List?;
      if (corpo['code'] != 'Ok' || rotas == null || rotas.isEmpty) throw Exception('sem rota');
      final r = rotas.first as Map<String, dynamic>;
      final coords = (r['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      final rota = Rota(
        pontos: coords.length >= 2 ? coords : [a, b],
        distanciaKm: (r['distance'] as num).toDouble() / 1000,
        duracaoMin: (r['duration'] as num).toDouble() / 60,
        pelasRuas: true,
      );
      _cache[_chave(a, b)] = rota;
      return rota;
    } catch (e) {
      debugPrint('Rota pelas ruas indisponível, usando linha reta: $e');
      return Rota.linhaReta(a, b); // não vai para o cache: tenta de novo depois
    }
  }
}
