# Музыка и эффекты Montezuma NES

Три музыкальные программы и девять SFX из локального `orig/nes/monty.nes`.
`src/native` не используется и не изменяется. Автор музыки не установлен;
названия дорожек описывают места вызова в игре.

## Готовый результат

После извлечения открыть `build/nes/music/player.html` обычным браузером.
Это автономный HTML с данными, синтезатором, интерфейсом и встроенным NSF.
Он не обращается в сеть. Нажать «Играть» для музыки или строку эффекта.
Есть пауза, повтор, выключение отдельных каналов и сохранение выбранной
дорожки в WAV. Если браузер ограничивает AudioWorklet для локальных файлов,
открыть эту же папку через локальный HTTP:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/nes/music
```

Затем открыть <http://127.0.0.1:8765/player.html>.

- `monty.nsf`: оригинальный 6502-драйвер, 12 дорожек, NTSC.
- `music.json`: начальные записи APU и события `[кадр, адрес, значение]`.
- `music-data.js`: те же данные для браузера.
- `apu.js`: самостоятельный синтезатор, работает в браузере и Node.js.
- `player.js`: интерфейс и AudioWorklet; `index.html`: раздельная версия плеера.
- `*.wav`: 44 100 Гц, mono PCM16; музыка — два цикла с затуханием,
  SFX — один эффект с коротким тихим хвостом.
- `verification.json`, `independent_verification.json`,
  `render_verification.json`: результаты проверок.

## Повторить извлечение

Из корня репозитория, Python 3.10+ и Node.js, без сторонних Python/npm-пакетов:

```sh
python3 tools/nes/music/extract_music.py orig/nes/monty.nes build/nes/music
node tools/nes/music/render_music.js build/nes/music
node tools/nes/music/test_apu.js build/nes/music
python3 tools/nes/music/verify_music.py orig/nes/monty.nes build/nes/music
python3 tools/nes/music/package_music.py build/nes/music build/nes/monty-nes-music.zip
```

Независимая проверка использует установленный MAME и, при наличии, `libgme`
(Game Music Emu). `--skip-mame` пропускает MAME; отсутствие libgme явно записывается
в JSON. Остальные команды не требуют эмуляторов. Обёртка ROM принимает только
SHA-256 разобранного образа. ROM в архив не включается.

Для автономного архива исходники лежат в `source/tools/nes/`; команды выполняются
из `source`, с явным путём к собственному локальному ROM и папке результата.

## Использовать JS отдельно

```js
const fs = require('node:fs');
const apu = require('./apu.js');
const data = JSON.parse(fs.readFileSync('music.json', 'utf8'));
const track = data.tracks.find(t => t.id === 'sfx_jump');
const audio = apu.render(track, 44100, data.framePeriod);
fs.writeFileSync('jump.wav', Buffer.from(apu.wav(audio.samples, audio.rate)));
```

В браузере `MontyAPU.EventPlayer` выдаёт очередной sample через `sample()`;
при повторе сохраняет состояние таймеров и LFSR. См. интеграцию в `player.js`.

Звук шеста процедурный: здесь записан пример Y=64…190, +2 за кадр, затем
остановка на 64-м кадре. Его высота/длина в игре зависят от траектории.
Остальные SFX выгружены при обычном игровом темпе — 8 кадров на шаг;
драйвер может проигрывать их с другой скоростью при другом музыкальном темпе.

JS моделирует два pulse, triangle и noise с фильтрами и нелинейным микшером.
События имеют точность кадра; точные CPU-такты записей не воспроизводятся.
Это специализированный плеер этих данных, не универсальный NSF-эмулятор.
Для аппаратно более точного исполнения оригинального кода использовать NSF.

Подробный разбор адресов и формата: `docs/NES_MUSIC.md` в репозитории,
либо `NES_MUSIC.md` в готовом архиве. Полученные игровые данные остаются
в игнорируемом `build/nes/music`; исходники не содержат ROM или музыкальных байтов.
