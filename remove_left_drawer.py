import os
import glob
import re

base_dir = r"c:\Users\46612581859\Desktop\nutriguard sem banco\nutriguard1\lib"

for filepath in glob.glob(os.path.join(base_dir, "**", "*.dart"), recursive=True):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    
    dirty = False
    
    # Remove lines containing the left drawer parameter
    if re.search(r'^\s*drawer:\s*(const\s+)?AppDrawer\(\),.*$', content, flags=re.MULTILINE):
        content = re.sub(r'^\s*drawer:\s*(const\s+)?AppDrawer\(\),?.*$\n?', '', content, flags=re.MULTILINE)
        dirty = True
        
    # Remove imports for app_drawer.dart
    if 'app_drawer.dart' in content:
        content = re.sub(r"^import\s+.*app_drawer\.dart'.*$\n?", "", content, flags=re.MULTILINE)
        dirty = True

    if dirty:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)

print("Left drawer references removed successfully.")
