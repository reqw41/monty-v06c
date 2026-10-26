# Monty → Вектор-06Ц: старт следующей сессии

Состояние на 26.10.2026 — заготовка. Решение владельца: ресурсы берём из MSX- или
Coleco-версии, код пишем заново; разбор в Ghidra и SkoolKit, как в bounder-v06c.

## Что брать из архива (не переписывать заново без нужды)
- `archive/Monty/docs/reference/gfx-format.md` — режим G1, базы VRAM меню и игры; `archive/Monty/extracted/` — снятая графика уровня 1.
- `archive/Monty/docs/reference/sound.md` — PSG-плеер 6108–61CB.
- `archive/Monty/CONTEXT.md` — карта ROM и I/O MSX-версии.
- `archive/monty-v06c-pi/stage2-accepted` — проверенный дизассемблер MSX (18 дампов, 4721 точка входа);
  `stage3-memory` — использование памяти; `stage4-vdp` — все 45 мест вывода в VDP.

## Первые шаги
1. Выбрать основу: MSX (образ есть) или Coleco (нужен образ в `orig/coleco/`). Сравнить объём и формат данных.
2. Перенести из bounder-v06c общие инструменты: `tools/msx1.js`, `tools/ghidra/run.sh`, `tools/build_skool.sh`, `tools/mkctl.py`, venv SkoolKit.
3. Снять образ в точке входа, создать `src/monty.ctl`, разметить данные: комнаты, тайлы, спрайты, музыка.
4. Экспортировать ресурсы в независимые от MSX файлы, затем писать движок для Вектора.
