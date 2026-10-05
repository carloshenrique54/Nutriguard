import 'package:flutter/material.dart';
import '../../widgets/custom_end_drawer.dart';

class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      
      appBar: AppBar(title: const Text('Configurações'),
        actions: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => CustomEndDrawer.showMenu(context),
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Image.asset(
                  'web/icons/1.png',
                  width: 32,
                  height: 32,
                  errorBuilder: (ctx, err, stack) => Image.asset('web/icons/1.png', width: 32, height: 32),
                ),
              ),
            ),
          ),
        ],),
      body: const Center(child: Text('Configurações do sistema (Em construção)')),
    );
  }
}
