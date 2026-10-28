import sys
import tempfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from services.metro_service import MetroService
from services.storage.file_service import FileService
from services.storage.config_service import ConfigService


def test_metro_empty_folder():
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        service = MetroService()
        data = service.build_metro(tmp_path)
        assert data["stations"] == []
        assert data["tracks"] == []
        assert data["segments"] == []


def test_metro_nested_blocks_and_interchange():
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        note1 = tmp_path / "1. Глава.txt"
        note1.write_text("""
Сцена 1 - План {
    Вайс {
        Вайс изучает план банка.
    }
    Маркус {
        Маркус готовит экипировку.
    }
}

Сцена 2 - Разведка {
    Вайс {
        Вайс идет к банку в одиночку.
    }
}
""", encoding="utf-8")

        note2 = tmp_path / "2. Глава.txt"
        note2.write_text("""
Сцена 3 - Ограбление {
    Вайс {
        Вайс взламывает замок.
    }
    Маркус {
        Маркус прикрывает вход.
    }
}
""", encoding="utf-8")

        service = MetroService()
        data1 = service.build_metro(tmp_path, active_file=note1)

        stations = data1["stations"]
        tracks = data1["tracks"]
        segments = data1["segments"]

        assert len(stations) == 2, f"Ожидалось 2 станции для 1. Глава, получено: {len(stations)}"
        assert stations[0]["title"] == "Сцена 1 - План"
        assert stations[0]["is_interchange"] is True
        assert "Вайс" in stations[0]["tracks"]
        assert "Маркус" in stations[0]["tracks"]

        assert stations[1]["title"] == "Сцена 2 - Разведка"
        assert stations[1]["is_interchange"] is False
        assert stations[1]["tracks"] == ["Вайс"]

        track_ids = [t["id"] for t in tracks]
        assert "Вайс" in track_ids
        assert "Маркус" in track_ids

        # Линия Вайс проходит через обе станции главы 1
        weiss_track = next(t for t in tracks if t["id"] == "Вайс")
        assert len(weiss_track["station_ids"]) == 2

        # Линия Маркус проходит через станцию 1
        marcus_track = next(t for t in tracks if t["id"] == "Маркус")
        assert len(marcus_track["station_ids"]) == 1

        assert len(segments) >= 2

        # Проверка изоляции второй главы (Один файл — одно метро)
        data2 = service.build_metro(tmp_path, active_file=note2)
        assert len(data2["stations"]) == 1
        assert data2["stations"][0]["title"] == "Сцена 3 - Ограбление"
        assert data2["stations"][0]["is_interchange"] is True


if __name__ == "__main__":
    test_metro_empty_folder()
    test_metro_nested_blocks_and_interchange()
    print("[OK] Все тесты MetroService пройдены успешно!")
