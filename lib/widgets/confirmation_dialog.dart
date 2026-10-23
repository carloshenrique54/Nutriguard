import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Exibe um modal de confirmação moderno e elegante para ações de exclusão.
/// Retorna `true` se o usuário confirmar a exclusão e `false` caso contrário.
Future<bool?> showDeleteConfirmationModal({
  required BuildContext context,
  required String title,
  required String itemName,
  String? itemDetail,
  IconData itemIcon = Icons.delete_outline,
  String confirmLabel = 'Sim, apagar',
  String cancelLabel = 'Cancelar',
}) {
  HapticFeedback.lightImpact();

  return showGeneralDialog<bool>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );

      return Stack(
        children: [
          // Fundo desfocado com efeito glassmorphism
          FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: curvedAnimation,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícone de alerta estilizado
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFECEF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFCD0D7), width: 2),
                        ),
                        child: const Icon(
                          Icons.delete_forever_rounded,
                          color: Color(0xFFC23147),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Título
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Subtítulo
                      Text(
                        'Tem certeza que deseja apagar?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Card com detalhes do item a ser excluído
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2E0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFD8A8), width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(itemIcon, color: const Color(0xFFC23147), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF333333),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (itemDetail != null && itemDetail.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      itemDetail,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Aviso de ação irreversível
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 15, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Esta ação não pode ser desfeita.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Botões de ação
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context, false);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  cancelLabel,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(context, true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC23147),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  confirmLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
