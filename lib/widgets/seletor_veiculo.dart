import 'package:flutter/material.dart';

import '../models/models.dart';

/// Lista os veículos do operador para ele escolher qual vai controlar.
/// Com [obrigatorio], a janela só fecha com uma escolha.
Future<DispositivoModel?> mostrarSeletorVeiculo(
  BuildContext context,
  List<DispositivoModel> veiculos, {
  String? atualId,
  bool obrigatorio = false,
}) {
  return showModalBottomSheet<DispositivoModel>(
    context: context,
    isDismissible: !obrigatorio,
    enableDrag: !obrigatorio,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFF2E0),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => PopScope(
      canPop: !obrigatorio,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Qual veículo você vai controlar?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC23147)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Você está vinculado a ${veiculos.length} veículos. Escolha um para iniciar.',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: veiculos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final v = veiculos[i];
                      final atual = v.id == atualId;
                      final placa = (v.placaVeiculo ?? '').trim().isNotEmpty ? v.placaVeiculo! : 'Sem placa';
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          key: Key('seletor_veiculo_${v.id}'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(ctx, v),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: atual ? const Color(0xFF8DB600) : Colors.black12,
                                width: atual ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC8E569),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2E7D32)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(placa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      if ((v.modeloVeiculo ?? '').isNotEmpty)
                                        Text(v.modeloVeiculo!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                      if ((v.nomeDispositivo ?? '').isNotEmpty)
                                        Text(v.nomeDispositivo!, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                                    ],
                                  ),
                                ),
                                Icon(
                                  atual ? Icons.check_circle : Icons.chevron_right,
                                  color: atual ? const Color(0xFF8DB600) : Colors.black38,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
