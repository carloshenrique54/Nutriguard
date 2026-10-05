import os
import glob
import re

base_dir = r"c:\Users\46612581859\Desktop\nutriguard sem banco\nutriguard1\lib"

# 1. Fix broken AppBars from previous step
bad_pattern = re.compile(r"(appBar:\s*AppBar\s*\(\s*title:\s*(?:const\s*)?Text\s*\([^,)]+)(,\s*actions:\s*\[)")
for filepath in glob.glob(os.path.join(base_dir, "screens", "**", "*.dart"), recursive=True):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    
    dirty = False
    if bad_pattern.search(content):
        content = bad_pattern.sub(r"\1)\2", content)
        dirty = True
        
    if dirty:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)

print("Fixed broken AppBars.")

# 2. Create CustomBottomNavBar widget
nav_bar_code = """import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int? selectedIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFC8E569),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildNavItem(0, Icons.notifications_none, 'Alertas'),
          _buildNavItem(1, Icons.description_outlined, 'Relatórios'),
          _buildNavItem(2, Icons.dashboard_rounded, 'Dashboard'),
          _buildNavItem(3, Icons.access_time, 'Histórico'),
          _buildNavItem(4, Icons.location_on_outlined, 'GPS'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: isActive
            ? Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC23147),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(icon, color: Colors.black87, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
"""

with open(os.path.join(base_dir, "widgets", "custom_bottom_nav_bar.dart"), "w", encoding="utf-8") as f:
    f.write(nav_bar_code)

print("Created CustomBottomNavBar.")

# 3. Inject CustomBottomNavBar into Dashboards and Perfil
dashboards = [
    ("screens/dashboard/dashboard_operador_screen.dart", "veiculo"),
    ("screens/dashboard/dashboard_veiculo_screen.dart", "veiculo"),
    ("screens/dashboard/dashboard_adm_frota_screen.dart", "frota")
]

for rel_path, suffix in dashboards:
    filepath = os.path.join(base_dir, rel_path)
    if os.path.exists(filepath):
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
        
        # Add import if missing
        if "custom_bottom_nav_bar.dart" not in content:
            content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../../widgets/custom_bottom_nav_bar.dart';")
        
        # Remove old FAB and BottomAppBar
        content = re.sub(r'floatingActionButton:\s*FloatingActionButton\(.*?\),.*?floatingActionButtonLocation:\s*FloatingActionButtonLocation\.centerDocked,', '', content, flags=re.DOTALL)
        
        # Replace BottomAppBar
        bottom_nav_replacement = f"""bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 2,
        onTap: (index) {{
          switch (index) {{
            case 0:
              Navigator.pushNamed(context, '/alertas-{suffix}');
              break;
            case 1:
              Navigator.pushNamed(context, '/relatorios-{suffix}');
              break;
            case 2:
              // Already on dashboard
              break;
            case 3:
              Navigator.pushNamed(context, '/historico-{suffix}');
              break;
            case 4:
              Navigator.pushNamed(context, '/gps');
              break;
          }}
        }},
      ),"""
        
        content = re.sub(r'bottomNavigationBar:\s*BottomAppBar\(.*?\),', bottom_nav_replacement, content, flags=re.DOTALL)
        
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)

print("Updated Dashboards.")

# 4. Inject into Perfil
perfil_path = os.path.join(base_dir, "screens/perfil/perfil_screen.dart")
if os.path.exists(perfil_path):
    with open(perfil_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    if "custom_bottom_nav_bar.dart" not in content:
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../../widgets/custom_bottom_nav_bar.dart';")
    
    # Perfil uses BottomAppBar but no FAB
    bottom_nav_replacement = """bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: -1,
        onTap: (index) {
          String suffix = role == UserRole.operador ? 'veiculo' : 'frota';
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/alertas-$suffix');
              break;
            case 1:
              Navigator.pushNamed(context, '/relatorios-$suffix');
              break;
            case 2:
              Navigator.pushNamed(context, role == UserRole.operador ? '/dashboard-operador' : '/dashboard-adm-frota');
              break;
            case 3:
              Navigator.pushNamed(context, '/historico-$suffix');
              break;
            case 4:
              Navigator.pushNamed(context, '/gps');
              break;
          }
        },
      ),"""
    
    content = re.sub(r'bottomNavigationBar:\s*BottomAppBar\(.*?\),', bottom_nav_replacement, content, flags=re.DOTALL)
    
    with open(perfil_path, "w", encoding="utf-8") as f:
        f.write(content)

print("Updated Perfil.")
