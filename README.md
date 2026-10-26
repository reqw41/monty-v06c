# Montezuma's Revenge → Вектор-06Ц

Порт Montezuma's Revenge (Parker Brothers) на ванильный Вектор-06Ц (КР580ВМ80А).
Основа — MSX-версия (конверсия Muffie), она совпадает с ColecoVision: внутри картридж Coleco
и BIOS OS7 (см. `docs/DISASM.md`). Ресурсы (графика, карты комнат, музыка) берём из оригинала, код пишем заново.
Разбор оригинала ведём в Ghidra и SkoolKit по образцу `~/projects/bounder-v06c`.

## Папки
- `orig/` (не в git) — исходные образы:
  - `msx/monty_msx.rom` — основной, id 1562, md5 6e83914112be54623f9f2403224d29b2, INIT 65B9h;
  - `msx/monty_msx_alt1560.rom` — близкая ревизия, md5 2172d188ae24507abb18695682749c54;
  - `atari/` — образ для Atari 8-bit (справочно);
- `src/` — разметка SkoolKit (`*.ctl`), затем исходник порта.
- `tools/` — модели, Ghidra headless, сборка.
- `docs/` — разбор и планы; старт сессии — `docs/NEXT-SESSION.md`.
- `archive/` (не в git) — прежние попытки, без изменений:
  - `Monty/` — ручная конверсия (июнь–сентябрь 2026), есть `CONTEXT.md`, извлечена графика G1, сделаны двери и переход между комнатами;
  - `monty-v06c-pi/` — линия Codex/Qwen: дизассемблирование, учёт памяти, VDP ABI; этапы лежат в worktree `stage2…stage5`;
  - `monty-recomp/` — ранняя попытка рекомпиляции.
