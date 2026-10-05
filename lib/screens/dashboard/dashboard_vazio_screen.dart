import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/custom_end_drawer.dart';

class DashboardVazioScreen extends StatelessWidget {
  const DashboardVazioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      
      appBar: AppBar(title: const Text('Dashboard'),
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
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 2),
      body: Column(
        children: [
          const Text('Nenhum dispositivo cadastrado, deseja Cadastrar um novo?'),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/cadastrar-dispositivo'),
            child: const Text('Cadastrar Dispositivo'),
          ),
        ],
      ),
    );
  }
}
