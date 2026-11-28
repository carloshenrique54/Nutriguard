import 'dart:async';

import 'package:flutter/material.dart';

/// Situação da conexão do sensor (ESP32/Wokwi) a partir da última leitura.
class SinalSensor {
  /// O ESP32 envia a cada 5 s; sem leitura há 20 s (4 envios perdidos) = desconectado.
  static const limite = Duration(seconds: 20);

  static bool conectado(DateTime? ultima, {DateTime? agora}) =>
      ultima != null && (agora ?? DateTime.now()).difference(ultima) < limite;

  static String _ha(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds < 0 ? 0 : d.inSeconds} s';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h';
    return '${d.inDays} dia(s)';
  }

  static String descricao(DateTime? ultima, {DateTime? agora}) {
    if (ultima == null) return 'Sensor nunca enviou dados';
    final d = (agora ?? DateTime.now()).difference(ultima);
    return conectado(ultima, agora: agora)
        ? 'Sensor conectado · leitura há ${_ha(d)}'
        : 'Sensor desconectado · última leitura há ${_ha(d)}';
  }
}

/// Selo verde (conectado, com pulso) ou cinza (desconectado). Atualiza sozinho
/// a cada segundo, então muda para "desconectado" mesmo sem dados novos.
class SeloSinalSensor extends StatefulWidget {
  final DateTime? ultimaLeitura;

  /// Só a bolinha e "Online"/"Offline" (listas).
  final bool compacto;

  const SeloSinalSensor({super.key, required this.ultimaLeitura, this.compacto = false});

  @override
  State<SeloSinalSensor> createState() => _SeloSinalSensorState();
}

class _SeloSinalSensorState extends State<SeloSinalSensor> {
  late final Timer _relogio;
  String _ultimoTexto = '';

  @override
  void initState() {
    super.initState();
    // Redesenha só quando o texto muda (ex.: "há 3 s" -> "há 4 s", ou conectado -> desconectado).
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _texto() != _ultimoTexto) setState(() {});
    });
  }

  String _texto() {
    final on = SinalSensor.conectado(widget.ultimaLeitura);
    return widget.compacto ? (on ? 'Online' : 'Offline') : SinalSensor.descricao(widget.ultimaLeitura);
  }

  @override
  void dispose() {
    _relogio.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = SinalSensor.conectado(widget.ultimaLeitura);
    final cor = on ? const Color(0xFF2E7D32) : const Color(0xFF757575);
    final fundo = on ? const Color(0xFFE8F5E9) : const Color(0xFFEEEEEE);
    final texto = _ultimoTexto = _texto();

    final bolinha = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        boxShadow: on ? [BoxShadow(color: cor.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)] : null,
      ),
    );

    return Container(
      key: const Key('selo_sinal_sensor'),
      padding: EdgeInsets.symmetric(horizontal: widget.compacto ? 8 : 10, vertical: widget.compacto ? 3 : 5),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          bolinha,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: widget.compacto ? 10 : 11.5, fontWeight: FontWeight.w600, color: cor),
            ),
          ),
        ],
      ),
    );
  }
}
