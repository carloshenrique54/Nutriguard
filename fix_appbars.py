import os
import glob
import re

base_dir = r"c:\Users\46612581859\Desktop\nutriguard sem banco\nutriguard1\lib"

# 1. Add Apple icon to all AppBars
appbar_pattern = re.compile(r'(appBar:\s*AppBar\s*\(\s*title:\s*[^,)]+)(,?)')

replacement = r"""\1,
        actions: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => Scaffold.of(context).openEndDrawer(),
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
        ]"""

for filepath in glob.glob(os.path.join(base_dir, "screens", "**", "*.dart"), recursive=True):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    
    dirty = False
    
    if 'appBar: AppBar(' in content and 'actions:' not in content:
        content = appbar_pattern.sub(replacement, content)
        dirty = True

    if dirty:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)


# 2. Fix CustomEndDrawer Apple Icon format to match exactly what the user asked
drawer_path = os.path.join(base_dir, "widgets", "custom_end_drawer.dart")
if os.path.exists(drawer_path):
    with open(drawer_path, "r", encoding="utf-8") as f:
        drawer_content = f.read()
    
    # Remove the color property from the Image.asset call
    drawer_content = drawer_content.replace(
        "color: const Color(0xFFC23147),",
        ""
    )
    with open(drawer_path, "w", encoding="utf-8") as f:
        f.write(drawer_content)

print("Updated AppBars and tweaked drawer icon.")
