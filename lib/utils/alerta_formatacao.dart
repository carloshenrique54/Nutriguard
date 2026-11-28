import 'package:flutter/material.dart';

import '../models/models.dart';

/// Transforma os códigos de alerta gravados pelo banco (ex.: `vibracao_excessiva`)
/// em textos legíveis para as telas.
class AlertaFormatacao {
  static const Map<String, String> _titulos = {
    'temperatura_alta': 'Temperatura acima do limite',
    'temperatura_baixa': 'Temperatura abaixo do limite',
    'umidade_alta': 'Umidade acima do limite',
    'umidade_baixa': 'Umidade abaixo do limite',
    'vibracao_excessiva': 'Vibração excessiva',
    'bateria_baixa': 'Bateria do dispositivo baixa',
    'porta_aberta': 'Porta do baú aberta',
    'viagem_finalizada': 'Viagem finalizada com relatório',
    'viagem_encerrada_sem_relatorio': 'Viagem encerrada sem relatório',
  };

  static const Map<String, String> _semAcento = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e', 'í': 'i',
    'ó': 'o', 'ô': 'o', 'õ': 'o', 'ú': 'u', 'ç': 'c',
  };

  /// "Vibração Excessiva" e "vibracao_excessiva" viram o mesmo código.
  static String _codigo(String? tipo) {
    var c = (tipo ?? '').trim().toLowerCase().replaceAll(' ', '_');
    _semAcento.forEach((de, para) => c = c.replaceAll(de, para));
    return c;
  }

  /// Título do alerta. Tipos conhecidos (com ou sem acento/espaço) viram o
  /// texto padrão; códigos desconhecidos viram texto com a primeira letra
  /// maiúscula (ex.: `sensor_offline` -> "Sensor offline").
  static String titulo(String? tipo) {
    final codigo = _codigo(tipo);
    if (codigo.isEmpty) return 'Alerta registrado';
    final conhecido = _titulos[codigo];
    if (conhecido != null) return conhecido;
    final original = tipo!.trim();
    if (!original.contains('_')) return original;
    final texto = original.replaceAll('_', ' ').toLowerCase();
    return texto[0].toUpperCase() + texto.substring(1);
  }

  /// Unidade do valor medido para o tipo de alerta.
  static String unidade(String? tipo) {
    final codigo = _codigo(tipo);
    if (codigo.startsWith('temperatura')) return '°C';
    if (codigo.startsWith('umidade') || codigo.startsWith('bateria')) return '%';
    if (codigo.startsWith('vibracao')) return ' m/s²';
    return '';
  }

  /// Aviso de fim de viagem (gerado pelo banco para gerente e ADM).
  static bool viagem(String? tipo) => _codigo(tipo).startsWith('viagem_');

  /// Fim de viagem sem o formulário "Parar viagem" (ex.: logout).
  static bool semRelatorio(String? tipo) => _codigo(tipo) == 'viagem_encerrada_sem_relatorio';

  /// Avisos que não indicam problema na carga: não mudam a situação do veículo
  /// (Normal/Atenção/Crítico) no painel da frota.
  static bool informativo(String? tipo) => viagem(tipo);

  /// Ícone e cores próprios dos avisos de viagem; `null` para alertas de sensor.
  static IconData? iconeViagem(String? tipo) {
    if (!viagem(tipo)) return null;
    return semRelatorio(tipo) ? Icons.assignment_late_outlined : Icons.assignment_turned_in_outlined;
  }

  static Color corViagem(String? tipo) => semRelatorio(tipo) ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
  static Color fundoViagem(String? tipo) => semRelatorio(tipo) ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9);

  /// "1h 25min", "40min".
  static String duracao(num minutos) {
    final m = minutos.round();
    if (m < 60) return '${m}min';
    final resto = m % 60;
    return resto == 0 ? '${m ~/ 60}h' : '${m ~/ 60}h ${resto}min';
  }

  /// Alertas de temperatura comprometem a carga: são tratados como críticos.
  static bool critico(String? tipo) {
    final codigo = _codigo(tipo);
    return codigo.startsWith('temperatura') || codigo.contains('critico');
  }

  /// Alerta resolvido? O banco usa "aberta"/"resolvida" e os dados de
  /// demonstração "Resolvido": compara sem diferenciar maiúsculas e gênero.
  static bool resolvido(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    return s.startsWith('resolvid') || s == 'fechada' || s == 'encerrada';
  }

  /// Texto do status para exibir: "Resolvido" ou "Pendente".
  static String status(String? status) => resolvido(status) ? 'Resolvido' : 'Pendente';

  static String numero(num valor) {
    final texto = valor == valor.roundToDouble() ? valor.toInt().toString() : valor.toStringAsFixed(1);
    return texto.replaceAll('.', ',');
  }

  /// Faixa permitida: "-2 a 8°C", "até 80%", "a partir de 10%" ou "--".
  static String faixa(num? min, num? max, String unidade) {
    if (min != null && max != null) return '${numero(min)} a ${numero(max)}$unidade';
    if (max != null) return 'até ${numero(max)}$unidade';
    if (min != null) return 'a partir de ${numero(min)}$unidade';
    return '--';
  }

  /// "8,1 m/s² · limite 6 m/s²" (ou "Porta aberta registrada" sem valor).
  static String detalhe(OcorrenciaModel o) {
    if (viagem(o.tipo)) {
      final dur = o.valorRegistrado != null ? 'Duração ${duracao(o.valorRegistrado!)}' : 'Duração não registrada';
      return semRelatorio(o.tipo) ? '$dur · sem formulário de parada' : '$dur · relatório de parada enviado';
    }
    final un = unidade(o.tipo);
    final partes = <String>[];
    if (o.valorRegistrado != null) partes.add('${numero(o.valorRegistrado!)}$un');
    if (o.limiteConfigurado != null) partes.add('limite ${numero(o.limiteConfigurado!)}$un');
    if (partes.isEmpty) return _codigo(o.tipo) == 'porta_aberta' ? 'Abertura registrada' : 'Sem valor registrado';
    return partes.join(' · ');
  }

  /// Nome do veículo para exibir: placa, senão nome do dispositivo.
  static String veiculo(String? idDispositivo, Iterable<DispositivoModel> dispositivos) {
    if (idDispositivo == null) return 'Veículo não identificado';
    for (final d in dispositivos) {
      if (d.id == idDispositivo) {
        final placa = (d.placaVeiculo ?? '').trim();
        if (placa.isNotEmpty) return placa;
        final nome = (d.nomeDispositivo ?? '').trim();
        if (nome.isNotEmpty) return nome;
      }
    }
    return 'Veículo';
  }

  /// "25/11 15:15"
  static String dataHora(DateTime? quando) {
    if (quando == null) return '';
    final l = quando.toLocal();
    String d2(int v) => v.toString().padLeft(2, '0');
    return '${d2(l.day)}/${d2(l.month)} ${d2(l.hour)}:${d2(l.minute)}';
  }
}
