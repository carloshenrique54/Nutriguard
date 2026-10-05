import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Text('Menu NutriGuard')),
          ListTile(
            title: const Text('Perfil (ADM)'),
            onTap: () => Navigator.pushNamed(context, '/perfil-adm'),
          ),
          ListTile(
            title: const Text('Perfil (Gerente)'),
            onTap: () => Navigator.pushNamed(context, '/perfil-gerente'),
          ),
          ListTile(
            title: const Text('Perfil (Operador)'),
            onTap: () => Navigator.pushNamed(context, '/perfil-operador'),
          ),
          ListTile(
            title: const Text('Cadastrar funcionário'),
            onTap: () => Navigator.pushNamed(context, '/cadastrar-funcionario'),
          ),
          ListTile(
            title: const Text('Cadastrar dispositivo'),
            onTap: () => Navigator.pushNamed(context, '/cadastrar-dispositivo'),
          ),
          ListTile(
            title: const Text('Criar frotas'),
            onTap: () => Navigator.pushNamed(context, '/criar-frota'),
          ),
          ListTile(
            title: const Text('Lista de dispositivos'),
            onTap: () => Navigator.pushNamed(context, '/listar-dispositivos'),
          ),
          ListTile(
            title: const Text('Lista de operadores'),
            onTap: () => Navigator.pushNamed(context, '/listar-operadores'),
          ),
          ListTile(
            title: const Text('Lista de frotas'),
            onTap: () => Navigator.pushNamed(context, '/listar-frotas'),
          ),
          ListTile(
            title: const Text('Configurações'),
            onTap: () => Navigator.pushNamed(context, '/configuracoes'),
          ),
          ListTile(
            title: const Text('Parar viagem'),
            onTap: () => Navigator.pop(context), 
          ),
        ],
      ),
    );
  }
}
