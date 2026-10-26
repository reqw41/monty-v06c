# Monty → Вектор-06Ц: старт следующей сессии

Состояние на 26.10.2026 — этап разбора; телепорт и читы в модели; формат комнат и ресурсы выгружены и сверены. Основа — MSX-версия (= ColecoVision, решение владельца).
Главное — `docs/DISASM.md`: MSX-версия — это картридж Coleco 8000–BFFF + BIOS OS7 в ОЗУ 0000–1FFF + прослойка Muffie 2000–25AE.

## Восстановить build/ с нуля
`build/`, `orig/`, `archive/`, `tools/.venv` не в git; оригиналы в `orig/msx/`.

    SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=dummy openmsx -machine MontyMSX -cart orig/msx/monty_msx.rom \
      -command "set renderer none" -script tools/openmsx/dump-entry.tcl
    python3 -I tools/build_image.py
    node tools/cmpsnap.js game20                      # сверка модели
    for l in 1 2 3; do node tools/cover_run.js $l; done          # обход 99 комнат телепортом
    for l in 1 2 3; do node tools/rooms.js $l; python3 tools/pyramid.py $l; done
    for l in 1 2 3; do node tools/room_nt.js $l; done; python3 -I tools/roomdec.py check   # 297 из 297
    python3 -I tools/export_res.py; python3 -I tools/objects.py; node tools/sfx.js; python3 -I tools/sfx_wav.py
    python3 -I tools/cov_entries.py; tools/ghidra/run.sh   # повторять, пока остаток не станет 816d 8179 9207
    python3 -m venv tools/.venv && tools/.venv/bin/pip install skoolkit==10.1
    tools/build_skool.sh

## Что брать из архива
- `archive/Monty/docs/reference/gfx-format.md`, `sound.md`; графика уровня 1 в `archive/Monty/extracted/`.
- `archive/monty-v06c-pi/stage4-vdp` — все места вывода в VDP (адреса относятся к тому же образу).

## Следующие шаги
1. Разметить в `src/monty.ctl` OS7 0000–1FFF только в объёме, который вызывает игра (по таблице переходов); остальное оставить данными.
2. Игра 8025–B104: главный цикл, комнаты, Панама Джо, враги, предметы. Данные 9377–A067, B105–BFFF: карты комнат, тайлы, спрайты, музыка.
3. Сделано: формат комнат (tools/roomdec.py) и ресурсы (tools/export_res.py), сверены по 297 комнатам.
   Сделано: интерфейс строк 0–4, предметы/двери/враги (начальное состояние), каталог объектов и спрайтов.
   Сделано: анимация E0/E8, лазеры, звук (10 эффектов, регистры AY по кадрам и WAV).
   Анимация героя и гибель — игровой код, переносится вместе с движком.
   Решения владельца: 3 плоскости (8 цветов), звук только ВИ53.
4. Порт работает (build/vec/monty.bin), логика сверена с MSX (docs/PORT_DESIGN.md). Дальше: скорость
   (сейчас ~21 итерация/с из 60), звук ВИ53, джойстик «П», ROM/дискета и проверка на MiSTer.
4. Звук: PSG через A0/A1 — понять, как Muffie переложил SN76489 на AY, и решить, что делать на Векторе (ВИ53 / AY).
5. Раскладка памяти Вектора: 16 КБ игры + свои услуги вместо OS7 + экран Graphics I -> плоскости.
