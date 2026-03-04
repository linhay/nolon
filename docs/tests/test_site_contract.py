import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "docs" / "index.html"


class SiteContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.html = INDEX.read_text(encoding="utf-8")

    def test_section_order_matches_flowdown_refresh(self):
        section_ids = re.findall(r'<section\s+id="([^"]+)"', self.html)
        expected = [
            "hero",
            "trust-strip",
            "quick-start",
            "console",
            "resource-center",
            "capabilities",
            "architecture",
            "ecosystem",
            "download",
            "faq",
        ]
        start = 0
        for section_id in expected:
            self.assertIn(section_id, section_ids, f"missing section: {section_id}")
            idx = section_ids.index(section_id)
            self.assertGreaterEqual(idx, start, f"section order broken at {section_id}")
            start = idx

    def test_navigation_targets_new_information_architecture(self):
        links = re.findall(r'<a\s+href="#([^"]+)"\s+data-i18n="nav\.[^"]+"', self.html)
        self.assertIn("capabilities", links)
        self.assertIn("console", links)
        self.assertIn("resource-center", links)
        self.assertNotIn("providers", links)
        self.assertNotIn("codex", links)
        self.assertNotIn("plugins", links)

    def test_legacy_anchors_are_kept_for_compatibility(self):
        self.assertRegex(self.html, r'id="providers"')
        self.assertRegex(self.html, r'id="codex"')
        self.assertRegex(self.html, r'id="plugins"')


if __name__ == "__main__":
    unittest.main()
