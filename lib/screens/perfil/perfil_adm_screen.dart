import 'package:flutter/material.dart';
import 'perfil_screen.dart';

class PerfilAdmScreen extends StatelessWidget {
  const PerfilAdmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerfilScreen(role: UserRole.adm);
  }
}
