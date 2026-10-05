import 'package:flutter/material.dart';
import '../../widgets/custom_end_drawer.dart';

class IniciarViagemScreen extends StatelessWidget {
  const IniciarViagemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      
      appBar: AppBar(title: const Text('Iniciar Viagem'),
        actions: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => CustomEndDrawer.showMenu(context),
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Image.asset(
                  'nutriguard1/web/icons/1.png',
                  width: 32,
                  height: 32,
                  errorBuilder: (ctx, err, stack) => const Icon(Icons.apple, color: Color(0xFFC23147), size: 32),
                ),
              ),
            ),
          ),
        ],),
      body: Column(
        children: [
          const Text('Para onde você vai?'),
          const TextField(decoration: InputDecoration(labelText: 'Destino da viagem')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iniciar viagem'),
          ),
        ],
      ),
    );
  }
}
