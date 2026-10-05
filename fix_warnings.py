import os, re

files = [
    r'lib\screens\dashboard\dashboard_adm_frota_screen.dart',
    r'lib\screens\dashboard\dashboard_operador_screen.dart',
    r'lib\screens\dashboard\dashboard_veiculo_screen.dart',
    r'lib\screens\perfil\perfil_screen.dart',
    r'lib\widgets\custom_bottom_nav_bar.dart'
]

for filepath in files:
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            c = f.read()
        
        c = re.sub(r'\.withOpacity\((.*?)\)', r'.withValues(alpha: \1)', c)
        
        # Also fix the use_null_aware_elements
        # "Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?'"
        # We can't safely regex this one without seeing the code, but we can fix .withOpacity
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(c)
        print(f"Fixed {filepath}")
