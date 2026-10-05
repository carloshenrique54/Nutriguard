import os
import glob

base_dir = r"c:\Users\46612581859\Desktop\nutriguard sem banco\nutriguard1\lib"

drawer_code = """import 'package:flutter/material.dart';

class CustomEndDrawer extends StatelessWidget {
  const CustomEndDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFFF2E0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
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
                      'nutriguard1/web/icons/1.png',
                      height: 40,
                      width: 40,
                      color: const Color(0xFFC23147),
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
                    children: const [
                      MenuListItem(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'Cadastrar funcionario',
                        routeName: '/cadastrar-funcionario',
                      ),
                      MenuListItem(
                        icon: Icons.add_box_outlined,
                        title: 'Cadastrar dispositivo',
                        routeName: '/cadastrar-dispositivo',
                      ),
                      MenuListItem(
                        icon: Icons.local_shipping_outlined,
                        title: 'Criar frotas',
                        routeName: '/criar-frota',
                      ),
                      MenuListItem(
                        icon: Icons.person_outline,
                        title: 'Perfil',
                        routeName: '/perfil',
                      ),
                      MenuListItem(
                        icon: Icons.receipt_long_outlined,
                        title: 'Lista de dispositivos',
                        routeName: '/listar-dispositivos',
                      ),
                      MenuListItem(
                        icon: Icons.people_alt_outlined,
                        title: 'Lista de operadores',
                        routeName: '/listar-operadores',
                      ),
                      MenuListItem(
                        icon: Icons.people_alt_outlined,
                        title: 'Lista de gerentes',
                        routeName: '/listar-gerentes',
                      ),
                      MenuListItem(
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
                        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
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
        Navigator.pop(context);
        Navigator.pushNamed(context, routeName);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFC23147), size: 24),
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
"""

os.makedirs(os.path.join(base_dir, "widgets"), exist_ok=True)
with open(os.path.join(base_dir, "widgets", "custom_end_drawer.dart"), "w", encoding="utf-8") as f:
    f.write(drawer_code)

# Add missing routes to main.dart
main_path = os.path.join(base_dir, "main.dart")
with open(main_path, "r", encoding="utf-8") as f:
    main_code = f.read()

if "'/perfil':" not in main_code:
    main_code = main_code.replace("'/perfil-adm':", "'/perfil': (context) => const PerfilAdmScreen(),\n        '/perfil-adm':")
if "'/listar-gerentes':" not in main_code:
    main_code = main_code.replace("'/listar-operadores':", "'/listar-gerentes': (context) => const ListarOperadoresScreen(), // Dummy\n        '/listar-operadores':")

with open(main_path, "w", encoding="utf-8") as f:
    f.write(main_code)

# Modify screens
target_apple_block = """        SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            'nutriguard1/web/icons/1.png',
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.apple, color: Color(0xFFC23147), size: 32),
          ),
        ),"""

replacement_apple_block = """        Builder(
          builder: (context) => GestureDetector(
            onTap: () => Scaffold.of(context).openEndDrawer(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'nutriguard1/web/icons/1.png',
                errorBuilder: (ctx, error, stackTrace) =>
                    const Icon(Icons.apple, color: Color(0xFFC23147), size: 32),
              ),
            ),
          ),
        ),"""

for filepath in glob.glob(os.path.join(base_dir, "screens", "**", "*.dart"), recursive=True):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    
    dirty = False
    
    if "CustomEndDrawer" not in content and "Scaffold(" in content:
        rel_path = os.path.relpath(filepath, os.path.join(base_dir, "screens"))
        depth = len(rel_path.split(os.sep)) - 1
        prefix = "../" * depth if depth > 0 else "./"
        import_stmt = f"import '{prefix}../widgets/custom_end_drawer.dart';"
        
        content = content.replace("import 'package:flutter/material.dart';", f"import 'package:flutter/material.dart';\n{import_stmt}")
        content = content.replace("Scaffold(", "Scaffold(\n      endDrawer: const CustomEndDrawer(),")
        dirty = True

    if target_apple_block in content:
        content = content.replace(target_apple_block, replacement_apple_block)
        dirty = True

    # Also handle the one in perfil_screen.dart which is slightly different
    target_apple_block_2 = """        SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            'nutriguard1/web/icons/1.png',
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.apple,
              color: Color(0xFFC23147),
              size: 32,
            ),
          ),
        ),"""
    
    if target_apple_block_2 in content:
        content = content.replace(target_apple_block_2, replacement_apple_block)
        dirty = True

    if dirty:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)

print("Updated drawer logic across files.")
