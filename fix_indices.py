import os
import glob
import re

base_dir = r"c:\Users\46612581859\Desktop\nutriguard sem banco\nutriguard1\lib\screens"

# Map filename prefix to correct index
index_map = {
    'alertas': '0',
    'relatorios': '1',
    'dashboard': '2',
    'historico': '3',
    'gps': '4',
    'perfil': '-1'
}

for filepath in glob.glob(os.path.join(base_dir, "**", "*.dart"), recursive=True):
    filename = os.path.basename(filepath)
    
    # Determine the correct index for this file
    correct_idx = None
    for prefix, idx in index_map.items():
        if filename.startswith(prefix):
            correct_idx = idx
            break
            
    if correct_idx is not None:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
            
        # Replace the selectedIndex
        new_content = re.sub(
            r'bottomNavigationBar:\s*const\s*CustomBottomNavBar\(selectedIndex:\s*-?\d+\),',
            f'bottomNavigationBar: const CustomBottomNavBar(selectedIndex: {correct_idx}),',
            content
        )
        
        if new_content != content:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(new_content)
            print(f"Fixed {filename} to index {correct_idx}")

print("Indices fixed.")
