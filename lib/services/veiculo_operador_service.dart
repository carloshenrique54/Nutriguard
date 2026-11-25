import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'trip_service.dart';

/// Lembra qual veículo o operador escolheu controlar quando ele tem mais de um.
///
/// Ordem de prioridade para decidir o veículo do operador:
///   1. o veículo da viagem em andamento (a viagem pertence a um veículo);
///   2. o veículo escolhido por ele anteriormente (salvo no aparelho);
///   3. o único veículo, quando ele tem apenas um.
/// Com mais de um veículo e nenhuma escolha, retorna null: a tela deve
/// pedir para o operador escolher.
class VeiculoOperadorService {
  static String _chave(String operadorId) => 'veiculo_escolhido_${operadorId.trim()}';

  Future<String?> escolhaSalva(String operadorId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chave(operadorId));
  }

  Future<void> salvarEscolha(String operadorId, String dispositivoId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave(operadorId), dispositivoId);
  }

  Future<DispositivoModel?> resolver(
    String operadorId,
    List<DispositivoModel> veiculos, {
    TripService? tripService,
  }) async {
    if (veiculos.isEmpty) return null;

    final viagem = await (tripService ?? TripService()).getActiveTrip(operadorId);
    if (viagem != null) {
      final daViagem = veiculos.where((v) => v.id == viagem.deviceId).firstOrNull;
      if (daViagem != null) return daViagem;
    }

    final salvo = await escolhaSalva(operadorId);
    if (salvo != null) {
      final escolhido = veiculos.where((v) => v.id == salvo).firstOrNull;
      if (escolhido != null) return escolhido;
    }

    return veiculos.length == 1 ? veiculos.first : null;
  }
}
