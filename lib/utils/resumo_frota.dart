import '../models/models.dart';
import 'alerta_formatacao.dart';

/// Números do painel da frota calculados a partir das leituras reais
/// (última medição de cada veículo) e das ocorrências.
class ResumoFrota {
  final double? temperaturaMedia;
  final double? umidadeMedia;
  final DateTime? ultimaLeitura;

  /// Veículos cuja última umidade passou do limite do próprio veículo.
  final int umidadeForaLimite;

  /// Limite de umidade quando todos os veículos usam o mesmo; senão `null`.
  final num? limiteUmidadeComum;

  final int criticos;
  final int atencao;
  final int normais;

  const ResumoFrota({
    this.temperaturaMedia,
    this.umidadeMedia,
    this.ultimaLeitura,
    this.umidadeForaLimite = 0,
    this.limiteUmidadeComum,
    this.criticos = 0,
    this.atencao = 0,
    this.normais = 0,
  });

  static bool _aberta(OcorrenciaModel o) => !AlertaFormatacao.resolvido(o.status);

  static ResumoFrota calcular(
    List<DispositivoModel> dispositivos,
    Map<String, MedicaoModel?> ultimas,
    List<OcorrenciaModel> ocorrencias,
  ) {
    final temps = <num>[];
    final umids = <num>[];
    DateTime? ultima;
    var umidFora = 0;

    for (final d in dispositivos) {
      final m = ultimas[d.id];
      if (m == null) continue;
      if (m.temperatura != null) temps.add(m.temperatura!);
      if (m.umidade != null) {
        umids.add(m.umidade!);
        final max = d.umidadeMaxima;
        final min = d.umidadeMinima;
        if ((max != null && m.umidade! > max) || (min != null && m.umidade! < min)) umidFora++;
      }
      final r = m.registradoEm;
      if (r != null && (ultima == null || r.isAfter(ultima))) ultima = r;
    }

    final limites = dispositivos.map((d) => d.umidadeMaxima).whereType<num>().toSet();

    // Situação por veículo: crítico (alerta de temperatura aberto) > atenção
    // (outro alerta aberto) > normal. Cada veículo conta uma vez só.
    final ids = dispositivos.map((d) => d.id).toSet();
    final criticos = <String>{};
    final atencao = <String>{};
    for (final o in ocorrencias) {
      final id = o.idDispositivo;
      if (id == null || !ids.contains(id) || !_aberta(o) || AlertaFormatacao.informativo(o.tipo)) continue;
      if (AlertaFormatacao.critico(o.tipo)) {
        criticos.add(id);
      } else {
        atencao.add(id);
      }
    }
    atencao.removeAll(criticos);

    double? media(List<num> v) => v.isEmpty ? null : v.fold<num>(0, (a, b) => a + b) / v.length;

    return ResumoFrota(
      temperaturaMedia: media(temps),
      umidadeMedia: media(umids),
      ultimaLeitura: ultima,
      umidadeForaLimite: umidFora,
      limiteUmidadeComum: limites.length == 1 ? limites.first : null,
      criticos: criticos.length,
      atencao: atencao.length,
      normais: dispositivos.length - criticos.length - atencao.length,
    );
  }

  /// "agora mesmo", "5 minuto(s) atrás", "3h atrás", "2 dia(s) atrás".
  static String tempoDesde(DateTime? quando, {DateTime? agora}) {
    if (quando == null) return 'Sem leituras';
    final diff = (agora ?? DateTime.now()).difference(quando);
    if (diff.inMinutes < 1) return 'agora mesmo';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minuto(s) atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    return '${diff.inDays} dia(s) atrás';
  }
}
