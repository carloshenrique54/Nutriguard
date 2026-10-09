import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

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

class _MenuContent extends StatefulWidget {
  const _MenuContent();

  @override
  State<_MenuContent> createState() => _MenuContentState();
}

class _MenuContentState extends State<_MenuContent> {
  final SupabaseService _supabase = SupabaseService();
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId != null) {
      final perfil = await _supabase.getUsuarioPerfil(currentUserId);
      if (perfil != null && mounted) {
        setState(() {
          _userRole = perfil.role;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
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
                    'assets/images/logo.png',
                    height: 40,
                    width: 40,
                    color: const Color(0xFFC23147),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    if (_userRole == 'admin') ...[
                      const MenuListItem(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'Cadastrar funcionário',
                        routeName: '/cadastrar-funcionario',
                      ),
                      const MenuListItem(
                        icon: Icons.add_box_outlined,
                        title: 'Cadastrar dispositivo',
                        routeName: '/cadastrar-dispositivo',
                      ),
                      const MenuListItem(
                        icon: Icons.local_shipping_outlined,
                        title: 'Criar frotas',
                        routeName: '/criar-frota',
                      ),
                      const MenuListItem(
                        icon: Icons.person_outline,
                        title: 'Perfil',
                        routeName: '/perfil-adm',
                      ),
                      const MenuListItem(
                        icon: Icons.receipt_long_outlined,
                        title: 'Lista de dispositivos',
                        routeName: '/listar-dispositivos',
                      ),
                      const MenuListItem(
                        icon: Icons.people_alt_outlined,
                        title: 'Lista de operadores',
                        routeName: '/listar-operadores',
                      ),
                      const MenuListItem(
                        icon: Icons.people_alt_outlined,
                        title: 'Lista de gerentes',
                        routeName: '/listar-gerentes',
                      ),
                      const MenuListItem(
                        icon: Icons.fire_truck_outlined,
                        title: 'Lista de frotas',
                        routeName: '/listar-frotas',
                      ),
                    ] else if (_userRole == 'gerente') ...[
                      const MenuListItem(
                        icon: Icons.person_outline,
                        title: 'Perfil',
                        routeName: '/perfil-gerente',
                      ),
                      const MenuListItem(
                        icon: Icons.receipt_long_outlined,
                        title: 'Lista de dispositivos',
                        routeName: '/listar-dispositivos',
                      ),
                      const MenuListItem(
                        icon: Icons.people_alt_outlined,
                        title: 'Lista de operadores',
                        routeName: '/listar-operadores',
                      ),
                    ] else if (_userRole == 'operador') ...[
                      const MenuListItem(
                        icon: Icons.person_outline,
                        title: 'Perfil',
                        routeName: '/perfil-operador',
                      ),
                      MenuListItem(
                        icon: Icons.stop_circle_outlined,
                        title: 'Parar viagem',
                        onTapAction: () {
                          // TODO: Implementar lógica de parar viagem
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Viagem parada com sucesso!')),
                          );
                        },
                      ),
                    ],
],
                ),
              ),
              
              // Footer Logout
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _supabase.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                      }
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
      ),
    );
  }
}

class MenuListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? routeName;
  final VoidCallback? onTapAction;

  const MenuListItem({
    super.key,
    required this.icon,
    required this.title,
    this.routeName,
    this.onTapAction,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        if (onTapAction != null) {
          onTapAction!();
        } else if (routeName != null) {
          Navigator.pushNamed(context, routeName!);
        }
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
