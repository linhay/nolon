import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
XCSTRINGS_PATH = os.path.join(SCRIPT_DIR, "../nolon/Localizable.xcstrings")
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "missing_translations.json")

def main():
    if not os.path.exists(XCSTRINGS_PATH):
        print(f"Error: {XCSTRINGS_PATH} not found.")
        return

    with open(XCSTRINGS_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    strings = data.get("strings", {})
    missing_items = {}

    for key, value in strings.items():
        localizations = value.get("localizations", {})
        zh_hans = localizations.get("zh-Hans")

        # Check if translation is missing or state is not 'translated'
        is_missing = True
        if zh_hans:
            string_unit = zh_hans.get("stringUnit", {})
            state = string_unit.get("state")
            if state == "translated":
                is_missing = False
        
        if is_missing:
            comment = value.get("comment", "")
            # We use the key as the source text source
            missing_items[key] = {
                "source": key, # xcstrings keys are the source text usually
                "comment": comment
            }

    print(f"Found {len(missing_items)} missing translations.")
    
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(missing_items, f, ensure_ascii=False, indent=2)

    print(f"Exported to {OUTPUT_PATH}")

if __name__ == "__main__":
    main()
