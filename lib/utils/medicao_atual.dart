import '../models/models.dart';

/// Leitura "atual" do veículo para os painéis: para cada grandeza, o valor
/// mais recente que chegou de verdade. O DHT22 às vezes falha (temperatura e
/// umidade vêm nulas numa leitura); sem isso o painel piscava "--".
class MedicaoAtual {
  /// [cronologicas]: da mais antiga para a mais recente.
  static MedicaoModel? combinar(List<MedicaoModel> cronologicas) {
    if (cronologicas.isEmpty) return null;
    final ultima = cronologicas.last;
    T? recente<T>(T? Function(MedicaoModel m) campo) {
      for (final m in cronologicas.reversed) {
        final v = campo(m);
        if (v != null) return v;
      }
      return null;
    }

    return MedicaoModel(
      id: ultima.id,
      idDispositivo: ultima.idDispositivo,
      temperatura: recente((m) => m.temperatura),
      umidade: recente((m) => m.umidade),
      vibracao: recente((m) => m.vibracao),
      portaAberta: recente((m) => m.portaAberta),
      latitude: recente((m) => m.latitude),
      longitude: recente((m) => m.longitude),
      bateria: recente((m) => m.bateria),
      registradoEm: ultima.registradoEm,
    );
  }
}
