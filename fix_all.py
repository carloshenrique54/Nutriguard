import os
import glob
import re

base_dir = r"c:\Users\46612581859\Desktop\nutriguard sem banco\nutriguard1"

# 1. Fix syntax in screens
for filepath in glob.glob(os.path.join(base_dir, "lib", "screens", "**", "*.dart"), recursive=True):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    
    dirty = False
    
    # The broken AppBar syntax looks exactly like:
    #         ])),
    # right after the Builder for the Apple icon.
    # We want to replace it with:
    #         ],),
    if "]))," in content:
        content = content.replace("])),", "],),")
        dirty = True

    if dirty:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)

# 2. Fix widget_test.dart
test_path = os.path.join(base_dir, "test", "widget_test.dart")
if os.path.exists(test_path):
    with open(test_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    if "MyApp" in content:
        content = content.replace("MyApp", "NutriGuardApp")
        with open(test_path, "w", encoding="utf-8") as f:
            f.write(content)

print("Syntax and tests fixed.")
