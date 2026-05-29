import os

file_path = r"lib\features\auth\presentation\pages\register_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the typo
cleaned_content = content.replace("Cam", "")

# Verify and save
with open(file_path, "w", encoding="utf-8") as f:
    f.write(cleaned_content)

print("Typo successfully fixed!")
