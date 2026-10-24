import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from services.content.document_outline import parse_user_dialect


def test_basic_blocks():
    text = """
Свободный текст в начале.

Сцена 1 - Допрос {
    Капитан: Где вы были вчера?
    Свидетель: Дома.
}

Сцена 2 - Улица {
    Шел сильный дождь.
}

Финальный текст в конце.
"""
    res = parse_user_dialect(text)
    assert len(res["errors"]) == 0, f"Ошибки: {res['errors']}"
    assert len(res["blocks"]) == 2
    assert res["blocks"][0]["name"] == "Сцена 1 - Допрос"
    assert "Капитан: Где вы были вчера?" in res["blocks"][0]["content"]
    assert res["blocks"][1]["name"] == "Сцена 2 - Улица"
    assert "Шел сильный дождь." in res["blocks"][1]["content"]


def test_duplicate_block_names():
    text = """
Интерьер бара {
    Сцена первая.
}

Интерьер бара {
    Сцена вторая (дубликат).
}
"""
    res = parse_user_dialect(text)
    assert len(res["errors"]) == 1
    assert "Duplicate block name" in res["errors"][0]


def test_dot_in_block_name():
    text = """
Файл.Сцена 1 {
    Ошибка: имя не должно содержать точку.
}
"""
    res = parse_user_dialect(text)
    assert len(res["errors"]) == 1
    assert "cannot contain '.'" in res["errors"][0]


def test_block_calls_transclusion():
    text = """
Введение.

Сцена 1 - Допрос()

Повторный вызов из другого файла:
Серия 1.Сцена 2 - Улица()

Ссылка на заметку:
[[Персонажи]]
[[Локации|Список мест]]
"""
    res = parse_user_dialect(text)
    assert len(res["errors"]) == 0

    # Локальный вызов
    assert len(res["local_calls"]) == 1
    assert res["local_calls"][0]["target_block"] == "Сцена 1 - Допрос"

    # Внешний вызов
    assert len(res["external_calls"]) == 1
    assert res["external_calls"][0]["target_file"] == "Серия 1"
    assert res["external_calls"][0]["target_block"] == "Сцена 2 - Улица"

    # Вики-ссылки
    assert "Персонажи" in res["wikilinks"]
    assert "Локации" in res["wikilinks"]


def test_code_block_escaping():
    text = """
Обычный блок {
    Тело обычного блока.
}

```python
# Здесь синтаксис не должен ломать парсер:
def foo():
    Блок_в_коде {
        some_code()
    }
    Ссылка: [[Файл_в_коде]]
```

Еще один блок {
    Тело после кода.
}
"""
    res = parse_user_dialect(text)
    assert len(res["errors"]) == 0
    assert len(res["blocks"]) == 2
    assert res["blocks"][0]["name"] == "Обычный блок"
    assert res["blocks"][1]["name"] == "Еще один блок"
    # Ссылка внутри кода не попала в wikilinks
    assert "Файл_в_коде" not in res["wikilinks"]


def test_nested_blocks():
    text = """
Сцена 1 - План {
    Обсуждение ограбления.

    Вайс {
        Вайс изучает чертежи банка.
    }

    Маркус {
        Маркус проверяет оружие.
    }
}
"""
    res = parse_user_dialect(text)
    assert len(res["errors"]) == 0, f"Ошибки: {res['errors']}"
    assert len(res["blocks"]) == 3

    # Проверяем иерархию блоков
    scene = next(b for b in res["blocks"] if b["name"] == "Сцена 1 - План")
    weiss = next(b for b in res["blocks"] if b["name"] == "Вайс")
    marcus = next(b for b in res["blocks"] if b["name"] == "Маркус")

    assert scene["level"] == 1
    assert scene["parent_name"] == ""
    assert "Вайс" in scene["children"]
    assert "Маркус" in scene["children"]

    assert weiss["level"] == 2
    assert weiss["parent_name"] == "Сцена 1 - План"
    assert "чертежи банка" in weiss["content"]

    assert marcus["level"] == 2
    assert marcus["parent_name"] == "Сцена 1 - План"
    assert "проверяет оружие" in marcus["content"]


if __name__ == "__main__":
    test_basic_blocks()
    test_duplicate_block_names()
    test_dot_in_block_name()
    test_block_calls_transclusion()
    test_code_block_escaping()
    test_nested_blocks()
    print("[OK] Все тесты пользовательского парсера пройдены успешно!")

