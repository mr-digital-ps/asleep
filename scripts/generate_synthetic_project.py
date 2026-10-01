"""
generate_synthetic_project.py — Генератор реалистичного синтетического проекта сценариев
с богатой, хаотичной историей ревизий (SQLite snapshots в .asleep/).

Спецификация данных:
- Наш пользовательский диалект (блоки Имя { ... }, вызовы трансклюзии Имя(), Файл.Имя(), [[Вики-ссылки]]).
- Хаотичные правки: добавление сцен, переименование персонажей, появление улик,
  удаление черновиков, внешние вызовы между сериями, ветвления.
- Множество снимков в SQLite (.asleep/history.db).
"""

import sys
import shutil
import time
from pathlib import Path
from datetime import datetime, timedelta

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from services.history.history_service import HistoryService
from services.graph.graph_service import GraphService
from services.storage.file_service import FileService
from services.storage.config_service import ConfigService


def build_synthetic_vault(target_dir: Path):
    target_dir.mkdir(parents=True, exist_ok=True)
    # Удаляем старые md файлы перед генерацией
    for p in target_dir.glob("*.md"):
        try:
            p.unlink()
        except Exception:
            pass

    cfg_svc = ConfigService()
    file_svc = FileService(cfg_svc)
    history_svc = HistoryService(file_svc, None)
    graph_svc = GraphService(None, file_svc, cfg_svc)
    history_svc.graph_service = graph_svc

    print(f"[*] Создание синтетического проекта в: {target_dir}")

    base_time = time.time() - (14 * 86400) # Начинаем 14 дней назад

    # --------------------------------------------------------------------------
    # СНИМОК 1: День 1. Первоначальный хаотичный набросок идеи
    # --------------------------------------------------------------------------
    t1 = base_time
    d1 = datetime.fromtimestamp(t1).strftime("%Y-%m-%d %H:%M:%S")

    (target_dir / "_notes.md").write_text(
        "- [[Заметки сценариста]]\n- [[Персонажи]]\n", encoding="utf-8"
    )

    (target_dir / "Заметки сценариста.md").write_text(
        "Идея детективного нуар-сериала 'Тени Порт-Артура'.\n\n"
        "Главный герой — уставший следователь [[Персонажи]].\n"
        "Сеттинг: дождливый приморский город, контрабанда и заброшенные склады.\n",
        encoding="utf-8"
    )

    (target_dir / "Персонажи.md").write_text(
        "Инспектор Морган {\n"
        "    Возраст: 48 лет.\n"
        "    Опытный детектив убойного отдела.\n"
        "    Привычка курить трубку во время допроса.\n"
        "}\n\n"
        "Джеймс - информатор {\n"
        "    Мелкий карманник из доков.\n"
        "}\n",
        encoding="utf-8"
    )

    graph_svc.invalidate_cache(target_dir)
    g1 = graph_svc.build_graph(target_dir)
    history_svc.create_snapshot(target_dir, trigger="manual", description="Первый набросок идеи и персонажей",
                                graph_data=g1, force=True, custom_timestamp=t1, custom_created_at=d1)
    print("  -> Снимок 1 создан (День 1)")

    # --------------------------------------------------------------------------
    # СНИМОК 2: День 3. Рождение первой серии и новая улика
    # --------------------------------------------------------------------------
    t2 = base_time + (2 * 86400) + 3600
    d2 = datetime.fromtimestamp(t2).strftime("%Y-%m-%d %H:%M:%S")

    (target_dir / "Серия 1 - Ночной гудок.md").write_text(
        "Холодный вечер в порту. Дождь бьет по ржавым контейнерам.\n\n"
        "Сцена 1 - Обнаружение { \n"
        "    В каюте брошенного сухогруза находят открытый сейф.\n"
        "    Следователь осматривает [[Улики]].\n"
        "}\n\n"
        "Входит [[Персонажи]]:\n"
        "Персонажи.Инспектор Морган()\n",
        encoding="utf-8"
    )

    (target_dir / "Улики.md").write_text(
        "Бронзовый ключ {\n"
        "    Найден на полу у сейфа. Гравировка: 'Склад №7'.\n"
        "}\n",
        encoding="utf-8"
    )

    (target_dir / "_notes.md").write_text(
        "- [[Заметки сценариста]]\n- [[Серия 1 - Ночной гудок]]\n- [[Персонажи]]\n- [[Улики]]\n",
        encoding="utf-8"
    )

    graph_svc.invalidate_cache(target_dir)
    g2 = graph_svc.build_graph(target_dir)
    history_svc.create_snapshot(target_dir, trigger="save", description="Черновик Серии 1 и добавление улик",
                                graph_data=g2, force=True, custom_timestamp=t2, custom_created_at=d2)
    print("  -> Снимок 2 создан (День 3)")

    # --------------------------------------------------------------------------
    # СНИМОК 3: День 5. Доработка персонажей, конфликт, переименования
    # --------------------------------------------------------------------------
    t3 = base_time + (4 * 86400) + 7200
    d3 = datetime.fromtimestamp(t3).strftime("%Y-%m-%d %H:%M:%S")

    (target_dir / "Персонажи.md").write_text(
        "Инспектор Морган {\n"
        "    Возраст: 48 лет.\n"
        "    Опытный детектив убойного отдела.\n"
        "    Привычка курить трубку во время допроса.\n"
        "    Тайна: хранит [[Улики]] в тайнике дома.\n"
        "}\n\n"
        "Джеймс - информатор {\n"
        "    Мелкий карманник из доков.\n"
        "    Связан с бандой 'Черный якорь'.\n"
        "}\n\n"
        "Вдова Элеонора {\n"
        "    Владелица судоходной компании.\n"
        "    Подозревает своего бухгалтера.\n"
        "}\n",
        encoding="utf-8"
    )

    (target_dir / "Серия 1 - Ночной гудок.md").write_text(
        "Холодный вечер в порту. Дождь бьет по ржавым контейнерам.\n\n"
        "Сцена 1 - Обнаружение { \n"
        "    В каюте брошенного сухогруза находят открытый сейф.\n"
        "    Следователь осматривает [[Улики]].\n"
        "}\n\n"
        "Персонажи.Инспектор Морган()\n\n"
        "Сцена 2 - Допрос информатора {\n"
        "    Морган прижимает карманника к мокрой кирпичной стене.\n"
        "    Информатор: 'Ключ ведет на склад №7, но там засада!'\n"
        "}\n",
        encoding="utf-8"
    )

    graph_svc.invalidate_cache(target_dir)
    g3 = graph_svc.build_graph(target_dir)
    history_svc.create_snapshot(target_dir, trigger="save", description="Ввод вдовы Элеоноры и допрос информатора",
                                graph_data=g3, force=True, custom_timestamp=t3, custom_created_at=d3)
    print("  -> Снимок 3 создан (День 5)")

    # --------------------------------------------------------------------------
    # СНИМОК 4: День 8. Ввод второй серии и перекрестные ссылки (внешний вызов)
    # --------------------------------------------------------------------------
    t4 = base_time + (7 * 86400) + 14000
    d4 = datetime.fromtimestamp(t4).strftime("%Y-%m-%d %H:%M:%S")

    (target_dir / "Серия 2 - Склад номер семь.md").write_text(
        "Утро следующего дня. Туман над гаванью.\n\n"
        "Воспоминание из прошлой ночи:\n"
        "Серия 1 - Ночной гудок.Сцена 2 - Допрос информатора()\n\n"
        "Сцена 1 - Штурм склада {\n"
        "    Инспектор Морган выбивает дверь плечом.\n"
        "    Внутри пусто, но пахнет свежим керосином.\n"
        "    На ящиках обнаружен [[Секретный шифр]].\n"
        "}\n",
        encoding="utf-8"
    )

    (target_dir / "Секретный шифр.md").write_text(
        "Записка шифром {\n"
        "    Ряд чисел: 12-45-89-01.\n"
        "    Координаты маяка на скале.\n"
        "}\n\n"
        "Связано с делом: [[Серия 1 - Ночной гудок]] и владельцем [[Персонажи]].\n",
        encoding="utf-8"
    )

    (target_dir / "_notes.md").write_text(
        "- [[Заметки сценариста]]\n"
        "- [[Серия 1 - Ночной гудок]]\n"
        "- [[Серия 2 - Склад номер семь]]\n"
        "- [[Персонажи]]\n"
        "- [[Улики]]\n"
        "- [[Секретный шифр]]\n",
        encoding="utf-8"
    )

    graph_svc.invalidate_cache(target_dir)
    g4 = graph_svc.build_graph(target_dir)
    history_svc.create_snapshot(target_dir, trigger="commit", description="Сценарий Серии 2 и Секретный шифр",
                                graph_data=g4, force=True, custom_timestamp=t4, custom_created_at=d4)
    print("  -> Снимок 4 создан (День 8)")

    # --------------------------------------------------------------------------
    # СНИМОК 5: День 11. Хаотичная перетасовка: удаление черновика, новые улики
    # --------------------------------------------------------------------------
    t5 = base_time + (10 * 86400) + 18000
    d5 = datetime.fromtimestamp(t5).strftime("%Y-%m-%d %H:%M:%S")

    # Переписываем Улики с добавлением новых карточек
    (target_dir / "Улики.md").write_text(
        "Бронзовый ключ {\n"
        "    Найден на полу у сейфа. Гравировка: 'Склад №7'.\n"
        "}\n\n"
        "Пуговица от дорогого пальто {\n"
        "    Золотая нить. Принадлежит [[Персонажи]].\n"
        "}\n\n"
        "Бутылка яда {\n"
        "    Следы мышьяка на пробке.\n"
        "}\n",
        encoding="utf-8"
    )

    # Добавляем хаоса в Заметки сценариста
    (target_dir / "Заметки сценариста.md").write_text(
        "Срочные правки от продюсера!\n\n"
        "Нужно усилить драматизм в [[Серия 2 - Склад номер семь]].\n"
        "Инспектор Морган должен сомневаться в лояльности информатора.\n"
        "Смотри [[Секретный шифр]] — перенести развязку на старый маяк.\n",
        encoding="utf-8"
    )

    graph_svc.invalidate_cache(target_dir)
    g5 = graph_svc.build_graph(target_dir)
    history_svc.create_snapshot(target_dir, trigger="save", description="Правки продюсера и новые улики",
                                graph_data=g5, force=True, custom_timestamp=t5, custom_created_at=d5)
    print("  -> Снимок 5 создан (День 11)")

    # --------------------------------------------------------------------------
    # СНИМОК 6: День 14 (Вчера). Финал акта и кульминация
    # --------------------------------------------------------------------------
    t6 = base_time + (13 * 86400) + 21000
    d6 = datetime.fromtimestamp(t6).strftime("%Y-%m-%d %H:%M:%S")

    (target_dir / "Серия 3 - Старый маяк.md").write_text(
        "Финал первой арки. Ночной шторм.\n\n"
        "Сцена 1 - Маяк {\n"
        "    Морган поднимается по винтовой лестнице.\n"
        "    В кармане лежит [[Улики]].\n"
        "    Наверху его ждет фигура в плаще.\n"
        "}\n\n"
        "Трансклюзия ключевого признания:\n"
        "Серия 1 - Ночной гудок.Сцена 2 - Допрос информатора()\n\n"
        "Сцена 2 - Развязка {\n"
        "    Выстрел гасит огонь маяка. Занавес.\n"
        "}\n",
        encoding="utf-8"
    )

    (target_dir / "_notes.md").write_text(
        "- [[Заметки сценариста]]\n"
        "- [[Серия 1 - Ночной гудок]]\n"
        "- [[Серия 2 - Склад номер семь]]\n"
        "- [[Серия 3 - Старый маяк]]\n"
        "- [[Персонажи]]\n"
        "- [[Улики]]\n"
        "- [[Секретный шифр]]\n",
        encoding="utf-8"
    )

    graph_svc.invalidate_cache(target_dir)
    g6 = graph_svc.build_graph(target_dir)
    history_svc.create_snapshot(target_dir, trigger="save", description="Серия 3 (Старый маяк) и финал первой арки",
                                graph_data=g6, force=True, custom_timestamp=t6, custom_created_at=d6)
    print("  -> Снимок 6 создан (День 14)")

    # --------------------------------------------------------------------------
    # СНИМОК 7: Сегодня (Актуальный Live)
    # --------------------------------------------------------------------------
    t7 = time.time()
    d7 = datetime.fromtimestamp(t7).strftime("%Y-%m-%d %H:%M:%S")

    (target_dir / "Заметки сценариста.md").write_text(
        "Текущий рабочий статус проекта:\n\n"
        "1. [[Серия 1 - Ночной гудок]] — утверждена в производство.\n"
        "2. [[Серия 2 - Склад номер семь]] — отправлена на вычитку редактору.\n"
        "3. [[Серия 3 - Старый маяк]] — черновик диалогов.\n\n"
        "База знаний персонажей: [[Персонажи]]\n"
        "Все улики: [[Улики]]\n",
        encoding="utf-8"
    )

    graph_svc.invalidate_cache(target_dir)
    g7 = graph_svc.build_graph(target_dir)
    history_svc.create_snapshot(target_dir, trigger="live", description="Текущее рабочее состояние",
                                graph_data=g7, force=True, custom_timestamp=t7, custom_created_at=d7)
    print("  -> Снимок 7 создан (Сегодня / Live)")

    print(f"\n[УСПЕХ] Синтетический проект готов! Создано 7 снимков в истории.")


if __name__ == "__main__":
    out_dir = PROJECT_ROOT / "test_notes"
    build_synthetic_vault(out_dir)
