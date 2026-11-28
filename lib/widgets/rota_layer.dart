import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/rota_service.dart';

/// Camada do mapa com a rota pelas ruas entre [origem] e [destino].
/// Enquanto a rota não chega (ou se o serviço falhar) mostra a linha reta
/// tracejada. Só recalcula quando a origem anda mais que [recalcularAcimaDeM]
/// (o GPS do veículo muda a cada poucos segundos).
class RotaLayer extends StatefulWidget {
  final LatLng origem;
  final LatLng destino;
  final double espessura;
  final double recalcularAcimaDeM;
  final ValueChanged<Rota>? aoCalcular;

  const RotaLayer({
    super.key,
    required this.origem,
    required this.destino,
    this.espessura = 4,
    this.recalcularAcimaDeM = 300,
    this.aoCalcular,
  });

  @override
  State<RotaLayer> createState() => _RotaLayerState();
}

class _RotaLayerState extends State<RotaLayer> {
  Rota? _rota;
  LatLng? _origemCalculada;
  LatLng? _destinoCalculado;

  @override
  void initState() {
    super.initState();
    _calcular();
  }

  @override
  void didUpdateWidget(RotaLayer old) {
    super.didUpdateWidget(old);
    const d = Distance();
    final destinoMudou = _destinoCalculado == null || d.as(LengthUnit.Meter, _destinoCalculado!, widget.destino) > 30;
    final origemAndou =
        _origemCalculada == null || d.as(LengthUnit.Meter, _origemCalculada!, widget.origem) > widget.recalcularAcimaDeM;
    if (destinoMudou || origemAndou) _calcular();
  }

  Future<void> _calcular() async {
    final origem = widget.origem;
    final destino = widget.destino;
    _origemCalculada = origem;
    _destinoCalculado = destino;
    final pronta = RotaService.instancia.emCache(origem, destino);
    if (pronta != null) {
      _rota = pronta;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.aoCalcular?.call(pronta));
      return;
    }
    final rota = await RotaService.instancia.calcular(origem, destino);
    if (!mounted || origem != _origemCalculada || destino != _destinoCalculado) return;
    setState(() => _rota = rota);
    widget.aoCalcular?.call(rota);
  }

  int _maisProximo(List<LatLng> pontos) {
    const d = Distance();
    var melhor = 0;
    var menor = double.infinity;
    // Só o início do trajeto: o veículo anda pouco entre recálculos.
    final limite = pontos.length < 400 ? pontos.length - 1 : 400;
    for (var i = 0; i < limite; i++) {
      final m = d.as(LengthUnit.Meter, widget.origem, pontos[i]);
      if (m < menor) {
        menor = m;
        melhor = i;
      }
    }
    return melhor;
  }

  @override
  Widget build(BuildContext context) {
    final rota = _rota;
    final pelasRuas = rota != null && rota.pelasRuas;
    // A rota começa na posição atual do veículo, a partir do ponto mais próximo
    // dela no trajeto calculado (o veículo anda entre um recálculo e outro).
    final pontos = pelasRuas ? [widget.origem, ...rota.pontos.skip(_maisProximo(rota.pontos) + 1)] : [widget.origem, widget.destino];
    return PolylineLayer(
      polylines: [
        if (pelasRuas)
          Polyline(points: pontos, color: Colors.white, strokeWidth: widget.espessura + 3),
        Polyline(
          points: pontos,
          color: const Color(0xFFC23147),
          strokeWidth: widget.espessura,
          pattern: pelasRuas ? const StrokePattern.solid() : StrokePattern.dashed(segments: const [8, 6]),
        ),
      ],
    );
  }
}
