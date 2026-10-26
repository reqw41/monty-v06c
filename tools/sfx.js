#!/usr/bin/env node
// Звуковые эффекты 0..9 (AC1A — запуск по таблице AD0B, AC6D — шаг на кадр) изолированно в модели:
// после старта игры прерывания запрещены, эффект запускается вызовом AC1A(A=n), затем AC6D раз в кадр,
// пока 702C бит 7 (эффект идёт). Регистры AY снимаются после каждого шага.
// -> build/res/sfx.json {n: [[r0..r10] по кадрам]}
'use strict';
const fs = require('fs');
const MSX1 = require('./msx1');
const out = {};
for (let n = 0; n < 10; n++) {
  const m = new MSX1().loadSnap('entry').startGame(1);
  m.callSub(0x1fd6, 2e6, { iff1: 0, iff2: 0 });   // TURN_OFF_SOUND, прерывания запрещены
  m.callSub(0xac1a, 2e6, { a: n, iff1: 0, iff2: 0 });
  const frames = [];
  for (let f = 0; f < 3000 && (m.mem[0x702c] & 0x80); f++) {
    m.callSub(0xac6d, 2e6, { iff1: 0, iff2: 0 });
    frames.push([...m.psg.subarray(0, 11)]);
  }
  out[n] = frames;
  console.log('эффект', n, 'кадров', frames.length);
}
fs.writeFileSync('build/res/sfx.json', JSON.stringify(out));
