import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "docs" / "index.html"
SCRIPT = ROOT / "docs" / "assets" / "js" / "site.js"


def extract_keys_for_lang(source: str, lang: str) -> set[str]:
    if lang == "zh":
        start_marker = "  zh: {"
        end_marker = "  },\n  en: {"
    else:
        start_marker = "  en: {"
        end_marker = "  }\n};"
    start = source.index(start_marker) + len(start_marker)
    end = source.index(end_marker, start)
    block = source[start:end]
    return set(re.findall(r'"([A-Za-z0-9_.-]+)"\s*:', block))


class I18nContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.html = INDEX.read_text(encoding="utf-8")
        self.script = SCRIPT.read_text(encoding="utf-8")

    def test_data_i18n_keys_exist_in_both_languages(self):
        page_keys = set(re.findall(r'data-i18n="([^"]+)"', self.html))
        zh_keys = extract_keys_for_lang(self.script, "zh")
        en_keys = extract_keys_for_lang(self.script, "en")
        self.assertTrue(page_keys.issubset(zh_keys), f"missing zh keys: {sorted(page_keys - zh_keys)}")
        self.assertTrue(page_keys.issubset(en_keys), f"missing en keys: {sorted(page_keys - en_keys)}")

    def test_zh_and_en_have_identical_key_sets(self):
        zh_keys = extract_keys_for_lang(self.script, "zh")
        en_keys = extract_keys_for_lang(self.script, "en")
        self.assertSetEqual(zh_keys, en_keys)


if __name__ == "__main__":
    unittest.main()
