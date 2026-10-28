"""Regression checks for project discovery and the shared configuration cascade."""
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

from PyQt6.QtCore import QUrl
from services.backend.main_backend import Backend
from services.content.block_parser import BlockEngine
from services.graph_service import GraphService
from services.history_service import HistoryService
from services.storage.config_service import ConfigService
from services.storage.file_service import FileService, list_project_notes


class ProjectArchitectureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def test_discovery_graph_blocks_history_and_sync_agree(self):
        source = self.write("Root.txt", "Shared {\n    old\n}\n[[deep/Note]]\n")
        nested = self.write("deep/Note.md", "Shared {\n    old\n}\nNested {\n    value\n}\n")
        for directory in (".hidden", ".git", ".asleep", ".obsidian", "__pycache__", "node_modules"):
            self.write(f"deep/{directory}/ignored.txt", "Shared { untouched }")
        self.write("_notes.txt", "Shared { untouched }")
        self.write("image.png", "not a note")
        expected = {"Root.txt", "deep/Note.md"}
        self.assertEqual({p.relative_to(self.root).as_posix() for p in list_project_notes(self.root)}, expected)

        files = FileService()
        engine = BlockEngine()
        engine.reindex_folder(self.root)
        self.assertTrue(engine.get_block("Nested")["found"])
        graph = GraphService().build_graph(self.root)
        urls = {QUrl.fromLocalFile(str(p)).toString() for p in (source, nested)}
        self.assertEqual({n["fileUrl"] for n in graph["nodes"] if n["type"] == "file"}, urls)
        self.assertTrue(any(edge["type"] == "link" for edge in graph["links"]))
        state, _ = HistoryService(files)._compute_folder_files_state(self.root)
        self.assertEqual(set(state), expected)

        backend = SimpleNamespace(block_engine=engine, file_service=files,
                                  blockUpdated=SimpleNamespace(emit=lambda *args: None),
                                  _current_folder=self.root, _is_syncing_files=False)
        Backend.sync_block(backend, QUrl.fromLocalFile(str(source)).toString(), "Shared", "updated")
        self.assertIn("updated", nested.read_text(encoding="utf-8"))
        self.assertNotIn("updated", source.read_text(encoding="utf-8"))
        self.assertIn("untouched", (self.root / "deep/node_modules/ignored.txt").read_text())

    def test_duplicate_basenames_keep_both_documents_and_blocks(self):
        self.write("a/Note.txt", "First {\n    one\n}\n")
        self.write("b/Note.txt", "Second {\n    two\n}\n")
        source = self.write("Root.txt", "[[a/Note]]\n[[Note]]\na/Note.First()\n")
        graph = GraphService().build_graph(self.root)
        self.assertEqual(sum(n["type"] == "file" for n in graph["nodes"]), 3)
        self.assertEqual(sum(n["type"] == "block" for n in graph["nodes"]), 2)
        source_url = QUrl.fromLocalFile(str(source)).toString()
        edges = [e for e in graph["links"] if e["source"] == source_url]
        self.assertEqual(sorted(e["type"] for e in edges), ["link", "transclusion"])

    def test_config_cascade_and_discovery_overrides(self):
        config = ConfigService()
        config.config_dir = self.root / "config"
        self.write("config/default/graph.json", '{"physics":{"a":1,"b":1}}')
        self.write("config/user/graph.json", '{"physics":{"b":2}}')
        self.write(".asleep/graph.json", '{"physics":{"a":3,"c":3}}')
        self.write("_graph_settings.json", '{"physics":{"a":4}}')
        graph = GraphService(config_service=config)
        self.assertEqual(graph.get_config(self.root), {"physics": {"a":4, "b":2, "c":3}})
        self.assertEqual(graph.get_config(self.root), config.get_graph_config(self.root))
        self.write(".asleep/app.json", json.dumps({"supported_extensions":[".md"], "ignored_directories":["skip"]}))
        self.write("include.md", "text")
        self.write("omit.txt", "text")
        self.write("skip/omit.md", "text")
        notes = list_project_notes(self.root, config_service=config)
        self.assertEqual([p.name for p in notes], ["include.md"])

    def test_reindex_drops_removed_blocks(self):
        note = self.write("nested/Note.txt", "Old {\n    value\n}")
        engine = BlockEngine()
        engine.reindex_folder(self.root)
        note.write_text("New {\n    value\n}", encoding="utf-8")
        engine.reindex_folder(self.root)
        self.assertFalse(engine.get_block("Old")["found"])
        self.assertTrue(engine.get_block("New")["found"])

    def test_get_story_timeline_extracts_stations_and_actors(self):
        from services.metro_service import MetroService
        self.write("01_Chapter.txt", "Duel {\n    1453 // The First Encounter\n    @John @Mary\n    Sword clash.\n}\n")
        self.write("02_Chapter.txt", "Ambush {\n    1455\n    @Mary @Guard\n    In the woods.\n}\n")
        service = MetroService(config_service=ConfigService())
        data = service.get_story_timeline(self.root)
        self.assertEqual(data["total"], 2)
        self.assertEqual(data["min_year"], 1453)
        self.assertEqual(data["max_year"], 1455)
        st0 = data["stations"][0]
        self.assertEqual(st0["name"], "Duel")
        self.assertEqual(st0["year"], 1453)
        self.assertEqual(st0["actors"], ["@John", "@Mary"])
        self.assertEqual(st0["note"], "The First Encounter")
        st1 = data["stations"][1]
        self.assertEqual(st1["name"], "Ambush")
        self.assertEqual(st1["actors"], ["@Mary", "@Guard"])

    def test_build_metro_multi_stage_transit_map(self):
        from services.metro_service import MetroService
        self.write("Эпоха 1.txt", "Station1 {\n    1453 // Epoch 1\n    @King @Knight\n    Content\n}\nStation1b {\n    1454 // Epoch 1 part 2\n    @King\n    Content\n}\n")
        self.write("Эпоха 2.txt", "Station2 {\n    1477 // Epoch 2\n    @King @Bishop\n    Content\n}\n")
        service = MetroService(config_service=ConfigService())
        # Проверка изоляции одного файла (Один файл — одно метро)
        res1 = service.build_metro(self.root, active_file=self.root / "Эпоха 1.txt")
        self.assertEqual(len(res1["stations"]), 2)
        self.assertEqual(len(res1["stages"]), 0)
        self.assertTrue(any(t["id"] == "King" for t in res1["tracks"]))
        king_track = next(t for t in res1["tracks"] if t["id"] == "King")
        self.assertEqual(len(king_track["station_ids"]), 2)
        self.assertTrue(any(s["track_id"] == "King" for s in res1["segments"]))

        res2 = service.build_metro(self.root, active_file=self.root / "Эпоха 2.txt")
        self.assertEqual(len(res2["stations"]), 1)
        self.assertEqual(res2["stations"][0]["title"], "Station2")


if __name__ == "__main__":
    unittest.main()

