import 'package:flutter/material.dart';
import 'perfil_screen.dart';

class PerfilGerenteScreen extends StatelessWidget {
  const PerfilGerenteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerfilScreen(role: UserRole.gerente);
  }
}
