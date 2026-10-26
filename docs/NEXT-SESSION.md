# Monty → Вектор-06Ц: старт следующей сессии

Состояние на 26.10.2026 — этап разбора. Основа — MSX-версия (= ColecoVision, решение владельца).
Главное — `docs/DISASM.md`: MSX-версия — это картридж Coleco 8000–BFFF + BIOS OS7 в ОЗУ 0000–1FFF + прослойка Muffie 2000–25AE.

## Восстановить build/ с нуля
`build/`, `orig/`, `archive/`, `tools/.venv` не в git; оригиналы в `orig/msx/`.

    SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=dummy openmsx -machine MontyMSX -cart orig/msx/monty_msx.rom \
      -command "set renderer none" -script tools/openmsx/dump-entry.tcl
    python3 -I tools/build_image.py
    node tools/cmpsnap.js game20                      # сверка модели
    for s in 1 2 3 4 5 6; do node tools/cover_run.js $s 40000; done
    python3 -I tools/cov_entries.py; tools/ghidra/run.sh   # повторять, пока остаток не станет 816d 8179
    python3 -m venv tools/.venv && tools/.venv/bin/pip install skoolkit==10.1
    tools/build_skool.sh

## Что брать из архива
- `archive/Monty/docs/reference/gfx-format.md`, `sound.md`; графика уровня 1 в `archive/Monty/extracted/`.
- `archive/monty-v06c-pi/stage4-vdp` — все места вывода в VDP (адреса относятся к тому же образу).

## Следующие шаги
1. Разметить в `src/monty.ctl` OS7 0000–1FFF только в объёме, который вызывает игра (по таблице переходов); остальное оставить данными.
2. Игра 8025–B104: главный цикл, комнаты, Панама Джо, враги, предметы. Данные 9377–A067, B105–BFFF: карты комнат, тайлы, спрайты, музыка.
3. Чит или телепорт в модели для обхода всех комнат уровней 1–3 и полного покрытия данных.
4. Звук: PSG через A0/A1 — понять, как Muffie переложил SN76489 на AY, и решить, что делать на Векторе (ВИ53 / AY).
5. Раскладка памяти Вектора: 16 КБ игры + свои услуги вместо OS7 + экран Graphics I -> плоскости.
