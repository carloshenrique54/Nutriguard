import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../repository/app_repository.dart';

class CustomEndDrawer {
  static void showMenu(BuildContext context) {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink(); // Built in transitionBuilder
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slideTween = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        return Stack(
          children: [
            // Background Blur
            FadeTransition(
              opacity: animation,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(
                    color: const Color(0x33000000),
                  ),
                ),
              ),
            ),
            // Slide Menu Content
            Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(
                position: slideTween,
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.height,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF2E0),
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
                      ),
                      child: const _MenuContent(),
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
}

class _MenuContent extends StatelessWidget {
  const _MenuContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: AppRepository.instance,
        builder: (context, child) {
          final role = AppRepository.instance.currentUser?.role ?? 'adm';

          return Stack(
            children: [
              // Close Button
              Positioned(
                top: 16,
                left: 0,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC23147),
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
                    ),
                    child: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ),
              ),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Right Icon
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, right: 16),
                      child: Image.asset(
                        'nutriguard1/web/icons/1.png',
                        height: 40,
                        width: 40,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.apple, color: Color(0xFFC23147), size: 40),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Menu Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        if (role == 'adm' || role == 'gerente')
                          const MenuListItem(
                            icon: Icons.person_add_alt_1_outlined,
                            title: 'Cadastrar funcionario',
                            routeName: '/cadastrar-funcionario',
                          ),
                        if (role == 'adm' || role == 'gerente')
                          const MenuListItem(
                            icon: Icons.add_box_outlined,
                            title: 'Cadastrar dispositivo',
                            routeName: '/cadastrar-dispositivo',
                          ),
                        if (role == 'adm')
                          const MenuListItem(
                            icon: Icons.local_shipping_outlined,
                            title: 'Criar frotas',
                            routeName: '/criar-frota',
                          ),
                        const MenuListItem(
                          icon: Icons.person_outline,
                          title: 'Perfil',
                          routeName: '/perfil',
                        ),
                        if (role == 'adm' || role == 'gerente')
                          const MenuListItem(
                            icon: Icons.receipt_long_outlined,
                            title: 'Lista de dispositivos',
                            routeName: '/listar-dispositivos',
                          ),
                        if (role == 'adm' || role == 'gerente')
                          const MenuListItem(
                            icon: Icons.people_alt_outlined,
                            title: 'Lista de operadores',
                            routeName: '/listar-operadores',
                          ),
                        if (role == 'adm')
                          const MenuListItem(
                            icon: Icons.people_alt_outlined,
                            title: 'Lista de gerentes',
                            routeName: '/listar-gerentes',
                          ),
                        if (role == 'adm' || role == 'gerente')
                          const MenuListItem(
                            icon: Icons.fire_truck_outlined,
                            title: 'Lista de frotas',
                            routeName: '/listar-frotas',
                          ),
                      ],
                    ),
                  ),
                  
                  // Footer Logout
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: () {
                          AppRepository.instance.logout();
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC23147),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Sair', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class MenuListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String routeName;

  const MenuListItem({
    super.key,
    required this.icon,
    required this.title,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        Navigator.pushNamed(context, routeName);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
