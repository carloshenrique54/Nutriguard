import 'package:flutter/material.dart';
import 'perfil_screen.dart';

class PerfilOperadorScreen extends StatelessWidget {
  const PerfilOperadorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerfilScreen(role: UserRole.operador);
  }
}
