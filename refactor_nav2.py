import os
import glob
import re

base_dir = r"c:\Users\46612581859\Desktop\nutriguard sem banco\nutriguard1\lib"

# 1. Write the new CustomBottomNavBar
nav_bar_code = """import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int? selectedIndex;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
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
          _buildNavItem(context, 0, Icons.notifications_none, 'Alertas', '/alertas-frota'),
          _buildNavItem(context, 1, Icons.description_outlined, 'Relatórios', '/relatorios-frota'),
          _buildNavItem(context, 2, Icons.dashboard_rounded, 'Dashboard', '/dashboard-adm-frota'),
          _buildNavItem(context, 3, Icons.access_time, 'Histórico', '/historico-frota'),
          _buildNavItem(context, 4, Icons.location_on_outlined, 'GPS', '/gps'),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label, String routeName) {
    final bool isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (!isActive) {
          Navigator.pushReplacementNamed(context, routeName);
        }
      },
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

# 2. Update screens
for filepath in glob.glob(os.path.join(base_dir, "screens", "**", "*.dart"), recursive=True):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    
    dirty = False
    
    if "Scaffold(" in content:
        # Add extendBody: true if not present
        if "extendBody: true" not in content:
            content = content.replace("Scaffold(", "Scaffold(\n      extendBody: true,")
            dirty = True
        
        # Replace CustomBottomNavBar(...) block
        if "CustomBottomNavBar(" in content:
            idx_match = re.search(r'selectedIndex:\s*(-?\d+)', content)
            if idx_match:
                idx = idx_match.group(1)
                content = re.sub(r'bottomNavigationBar:\s*CustomBottomNavBar\([\s\S]*?\),', f'bottomNavigationBar: const CustomBottomNavBar(selectedIndex: {idx}),', content)
                dirty = True
        
        # Replace AppBottomNav(...) block
        if "AppBottomNav(" in content:
            if "custom_bottom_nav_bar.dart" not in content:
                rel_path = os.path.relpath(filepath, os.path.join(base_dir, "screens"))
                depth = len(rel_path.split(os.sep)) - 1
                prefix = "../" * depth if depth > 0 else "./"
                import_stmt = f"import '{prefix}../widgets/custom_bottom_nav_bar.dart';"
                content = content.replace("import 'package:flutter/material.dart';", f"import 'package:flutter/material.dart';\n{import_stmt}")
            
            content = re.sub(r"import '.*?app_bottom_nav\.dart';\n", "", content)
            
            idx_match = re.search(r'currentIndex:\s*(\d+)', content)
            idx = idx_match.group(1) if idx_match else "-1"
            
            content = re.sub(r'bottomNavigationBar:\s*(?:const\s*)?AppBottomNav\([\s\S]*?\),', f'bottomNavigationBar: const CustomBottomNavBar(selectedIndex: {idx}),', content)
            dirty = True
            
    if dirty:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)

print("Nav refactored.")
