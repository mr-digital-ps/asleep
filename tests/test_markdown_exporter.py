import unittest
import tempfile
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.resolve()))
from services.content.markdown_exporter import dialect_to_markdown, MarkdownExporter


class MarkdownExporterTests(unittest.TestCase):
    def test_dialect_to_markdown_blocks_and_actors(self):
        source = """
Введение в сюжет

Сцена1 {
    @[Карл V] подписывает указ.
    Внешний.Фрагмент()
    Локальный()
}

Сцена2 {
    Финал события.
}
"""
        converted = dialect_to_markdown(source)
        self.assertIn("### Сцена1", converted)
        self.assertIn("**@Карл V**", converted)
        self.assertIn("![[Внешний#Фрагмент]]", converted)
        self.assertIn("![[#Локальный]]", converted)
        self.assertIn("### Сцена2", converted)
        self.assertNotIn("{", converted)
        self.assertNotIn("}", converted)

    def test_export_file(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            src_file = Path(tmp_dir) / "TestNote.txt"
            src_file.write_text("Блок { @[Актор] говорит привет. }", encoding="utf-8")

            res = MarkdownExporter.export_file(str(src_file))
            self.assertTrue(res["success"])
            self.assertEqual(res["fileName"], "TestNote.md")

            exported_file = Path(res["filePath"])
            self.assertTrue(exported_file.exists())
            content = exported_file.read_text(encoding="utf-8")
            self.assertIn("### Блок", content)
            self.assertIn("**@Актор**", content)


if __name__ == "__main__":
    unittest.main()
