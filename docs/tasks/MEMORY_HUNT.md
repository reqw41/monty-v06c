# Задача: найти ≥ 540 байт постоянной памяти в Monty (Вектор-06Ц, NES-порт)

## Контекст
Проект `~/projects/monty-v06c` — порт Montezuma's Revenge (вид и физика NES) на ванильный Вектор-06Ц, i8080, 64 КБ.
Память заполнена почти до байта. Готовые сдвиги врагов (пул `ps`, кэш спрайтов врагов) раздаются из свободных
кусков памяти при старте; сейчас из 32 сдвигов помещаются **17**, не влезают 15 (размеры 42×7 и 30×8 = **534 байта**).
Нужно найти ≥ 540 байт, которые можно отдать пулу сдвигов, **не меняя поведения игры**.

Журналы: `docs/BUGS.md` (fix1…fix18), `docs/NES_NATIVE.md`, `docs/FRAME_BUDGET.md`, `docs/VI53_MUSIC.md`. Ветка `main`.

## Сборка и проверка
- Сборка: `sh tools/nes/quick_build.sh build/<ваш_каталог>` (НЕ используйте `build/quick` и `build/cache` — их занимает другой агент).
  Перед сборкой, если меняли пул/музыку: `python3 tools/nes/music/to_vi53.py`.
- Образ ROM: `python3 tools/nes/build_splash.py --build build/<каталог> --output rom/<имя>.r0m --quick`.
- Стенды: `B=build/<каталог> node tools/bench/<имя>.js`. Полный набор: все `tools/bench/nes-*.js` + `restart-enemies.js`
  (без `*physics-audit*`, `*splash*`, `*ladder-gameplay*`). Физика против NES: `B=build/<каталог> sh tools/nes/diff_audits.sh`
  (ожидается 0 расхождений, кроме известных walljump 26 и belt 136).
- **Сейчас падают и до ваших правок (не чинить, не считать регрессией):** nes-anim-cadence, nes-chain-approach/descent/exit/landing/live/release/walk,
  nes-climb-audit/caps/live, nes-death-paths, nes-enemy-seeds, nes-ink-cost, nes-ink-planes, nes-joe-byte-special, nes-joe-prep-pair,
  nes-palette-rgb, nes-prep-fast, nes-preparation-cost (нестабилен), nes-room-entry, nes-room-transitions, nes-rope-top, nes-vase;
  и 8 стендов, требующих 32/≥29 сдвигов: nes-cache-lifetime, nes-cheat-pack, nes-frame-pacing, nes-joystick, nes-live-capacity,
  nes-live-code-bound, nes-pacing-raster, nes-title-animation — **они должны позеленеть, когда сдвиги вернутся.**

## Инструменты поиска
- `COVER=файл` и `ACCESS=файл` в `tools/vec_emu.js`: накапливают карту выполненных команд и обращений к памяти (объединяются между
  запусками). Пример: `COVER=/tmp/c.bin ACCESS=/tmp/a.bin B=build/x node tools/bench/<стенд>.js`.
  Внимание: «не тронуто стендами» ≠ «свободно». Ранее ловушки: страницы F9..FF — буферы фона спрайтов (байты 00..2F слота k = страница F9+k)
  и маски (D0..FF); `dlist` хвост используется при длинных списках; образ сохраняется только до FEC0 (`SAVEBIN … 0xFEC0`), выше — загрузчик.
- Распределение сдвигов: `node tools/bench/ps-alloc.js build/<каталог>` — перехват `nes_ps_alloc` (A = размер), результат `np_best/np_begin`; диапазоны пула —
  `gen/music_pages.asm`, генерируются `tools/nes/music/to_vi53.py` (список пар в конце `main()`).
- Карта символов: `build/native/monty.sym` (или `<каталог>/monty.sym`), профили — `tools/bench/walk-cost.js`, `pc-hist.js`.

## Где искать (кандидаты, проверить и измерить)
1. **Мёртвый код MSX/старых путей в сборке NES_FULL** (флаги сборки: `-DNES_JOE_3COLOR -DNES_JOE_BLEND80 -DNES_JOE_SP_RESTORE -DNES_LADDER_LOW
   -DNES_STABLE_COLORS`, `game.asm` сам задаёт NES_STYLE и NES_FULL). Например `joe_source0/1/2` (`joe_bands.asm`, ~390 байт «legacy restore»,
   при NES_STABLE_COLORS не копируются — проверить, что действительно мертвы, и что из них уже переиспользовано `nes_conveyor.asm`).
   Процедуры, на которые нет ссылок в этой конфигурации (статический анализ по исходникам с учётом IFDEF + карта COVER).
2. **Развёрнутые циклы** (`enemy_mix` REPT 16 ≈ 129 байт, `enemy_repaint_mix`, `jn_restore_*`, `fl_fast*`): свернуть, если это не на горячем
   пути, либо оценить цену в тактах (замер `walk-cost.js` в комнатах 2,8 и 5,6; допустимо ≤ 0,5 % скорости суммарно).
3. **Данные:** `title_packed` (1282 байта, картинка заставки ZX0 для GAME OVER), `full_raw` (1016, маски тайлов — дубли?), комнаты `nf_room_*`,
   `nf_object_lists`, таблицы Джо (`joe_row_lo/hi`, кадры). Лучшее сжатие/дедупликация, общий распаковщик (ZX0 `title_zx0` уже в образе).
4. **Переносимые окна:** код, который нужен только в загрузке/меню, но лежит в постоянной памяти (перенести в одноразовую область E000.. / boot).
5. Повторно используемые буферы (одновременно не живущие области), выравнивание страниц (`ALIGN 256` с пустыми хвостами).

## Ограничения
- Не менять поведение: стенды и аудиты физики — как до правок (кроме 8 стендов сдвигов, которые должны позеленеть).
- Не трогать: кэш двух образов Джо (3700..381D), код столкновений NES (3660..36FF, 3820..38B0, `nes_hit.asm`), музыку и её копию.
- Скорость не хуже: `ROOM=2,8 KEYS=walk` и `ROOM=5,6 KEYS=walk` в `walk-cost.js` (сейчас 45,5 и 26,8 шага/с), отклонение ≤ 0,5 %.
- Работать в отдельной ветке git (`mem-hunt`), коммиты — по одному найденному резерву.

## Что сдать
1. Отчёт `docs/MEMORY_HUNT.md`: таблица кандидатов — адрес, размер, почему свободен/как освобождён, доказательство (стенд/COVER/статика),
   цена в тактах; что проверено и отвергнуто (с причиной).
2. Ветка `mem-hunt` с правками; итог: сколько сдвигов из 32 помещаются (перехват `nes_ps_alloc`), результаты полного набора стендов и
   `diff_audits.sh`, скорость в 2,8 и 5,6.
