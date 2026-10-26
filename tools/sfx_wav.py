#!/usr/bin/env python3
"""build/res/sfx.json (регистры AY по кадрам) -> build/res/sfx_<n>.wav: простой синтез AY (такт 1789772 Гц,
кадр 1/60 с, громкость по логарифмической таблице AY, шум — LFSR 17 бит). Только для прослушивания и сверки."""
import json, struct, wave
CLK, RATE, FPS = 1789772, 44100, 60
VOL = [0, .0105, .0152, .0221, .0314, .0459, .0644, .107, .126, .204, .292, .372, .492, .609, .785, 1.0]
d = json.load(open('build/res/sfx.json'))
for n, frames in d.items():
    out = []; ph = [0.0] * 3; nz_ph = 0.0; lfsr = 1; nz = 1
    for r in frames + [[0] * 11] * 6:
        mix = r[7]
        per = [max(1, (r[2 * c] | (r[2 * c + 1] & 15) << 8)) for c in range(3)]
        npr = max(1, r[6] & 31)
        for _ in range(RATE // FPS):
            s = 0.0
            nz_ph += CLK / 16 / npr / RATE
            while nz_ph >= 1:
                nz_ph -= 1; bit = (lfsr ^ (lfsr >> 3)) & 1; lfsr = (lfsr >> 1) | (bit << 16); nz = lfsr & 1
            for c in range(3):
                ph[c] = (ph[c] + CLK / 16 / per[c] / RATE / 2) % 1.0
                t = 1 if (mix >> c) & 1 else (ph[c] < .5)
                q = 1 if (mix >> (c + 3)) & 1 else nz
                s += VOL[r[8 + c] & 15] * (1 if (t and q) else 0)
            out.append(int((s / 3 - .25) * 26000))
    w = wave.open(f'build/res/sfx_{n}.wav', 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes(b''.join(struct.pack('<h', max(-32768, min(32767, x))) for x in out)); w.close()
print('build/res/sfx_0..9.wav')
