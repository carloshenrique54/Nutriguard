import os
import glob
import re

base_dir = r"c:\Users\46612581859\Desktop\nutriguard sem banco\nutriguard1\lib\screens\dashboard"

for filepath in glob.glob(os.path.join(base_dir, "*.dart")):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Remove the dangling BottomAppBar parameters
    content = re.sub(r'\s*shape: const CircularNotchedRectangle\(\),.*?body: SafeArea\(', r'\n      body: SafeArea(', content, flags=re.DOTALL)
    
    # Remove the _buildBottomNavBtn method completely
    pattern = r'  Widget _buildBottomNavBtn\([\s\S]*?\}\n'
    content = re.sub(pattern, '', content)

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

print("Dashboards fixed.")
