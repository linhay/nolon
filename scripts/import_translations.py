import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
XCSTRINGS_PATH = os.path.join(SCRIPT_DIR, "../nolon/Localizable.xcstrings")
TRANSLATIONS_PATH = os.path.join(SCRIPT_DIR, "translated_items.json")

def main():
    if not os.path.exists(XCSTRINGS_PATH):
        print(f"Error: {XCSTRINGS_PATH} not found.")
        return
        
    if not os.path.exists(TRANSLATIONS_PATH):
        print(f"Error: {TRANSLATIONS_PATH} not found.")
        return

    # Load xcstrings
    with open(XCSTRINGS_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Load translations
    with open(TRANSLATIONS_PATH, 'r', encoding='utf-8') as f:
        translations = json.load(f)

    strings = data.get("strings", {})
    updated_count = 0

    for key, translation in translations.items():
        if key in strings:
            if "localizations" not in strings[key]:
                strings[key]["localizations"] = {}
            
            strings[key]["localizations"]["zh-Hans"] = {
                "stringUnit": {
                    "state": "translated",
                    "value": translation
                }
            }
            updated_count += 1
        else:
            print(f"Warning: Key '{key}' not found in xcstrings file.")

    # Save back
    with open(XCSTRINGS_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        
    print(f"Successfully updated {updated_count} translations in {XCSTRINGS_PATH}")

if __name__ == "__main__":
    main()
