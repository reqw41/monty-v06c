// Слой вывода JS-игры: вместо сравнения «было/стало» — отметки при записи (src/model/vdp.js: m.onVram при
// смене байта VRAM, m.onReg при записи регистра). Таблица имён — клетка; цвета — группа (8 тайлов); шаблоны
// текущего банка — тайл; смена банка (R4) — тайлы, у которых шаблоны банков различаются; включение экрана
// (R1 бит 6) — всё. render() по отметкам обновляет «экран» shown[768] (ключ клетки — шаблон и цвет её тайла),
// check() сверяет его с полным пересчётом: так проверяется полнота отметок — то же будет у вывода на Векторе.
'use strict';
const NT = 0x1800, COL = 0x2000;
const bankBase = (m) => (m.vreg[4] & 7) * 0x800;
function key(m, c) { const t = m.vram[NT + c], b = bankBase(m) + 8 * t; return Buffer.from(m.vram.subarray(b, b + 8)).toString('hex') + m.vram[COL + (t >> 3)].toString(16); }

function init(m) {
  m.vd = { cells: new Set(), tiles: new Set(), all: true, shown: new Array(768).fill(''), on: !!(m.vreg[1] & 0x40), bank: m.vreg[4] & 7, stat: { cells: 0, tiles: 0, all: 0, frames: 0 } };
  m.onVram = (mm, x) => {
    const vd = mm.vd;
    if (x >= NT && x < NT + 768) vd.cells.add(x - NT);
    else if (x >= COL && x < COL + 32) for (let t = 0; t < 8; t++) vd.tiles.add(8 * (x - COL) + t);
    else { const b = bankBase(mm); if (x >= b && x < b + 0x800) vd.tiles.add((x - b) >> 3); }
  };
  m.onReg = (mm, n, v) => {
    const vd = mm.vd;
    if (n === 4 && (v & 7) !== vd.bank) {                // смена банка: тайлы с разными шаблонами
      const o = vd.bank * 0x800, nb = (v & 7) * 0x800;
      for (let t = 0; t < 256; t++) for (let j = 0; j < 8; j++) if (mm.vram[o + 8 * t + j] !== mm.vram[nb + 8 * t + j]) { vd.tiles.add(t); break; }
      vd.bank = v & 7;
    }
    if (n === 1) { const on = !!(v & 0x40); if (on && !vd.on) vd.all = true; vd.on = on; }
  };
}
// render: отметки -> shown (клетки; клетки с отмеченными тайлами; всё)
function render(m) {
  const vd = m.vd; if (!vd.on) return;
  vd.stat.frames++;
  if (vd.all) { for (let c = 0; c < 768; c++) vd.shown[c] = key(m, c); vd.stat.all++; }
  else {
    for (const c of vd.cells) { vd.shown[c] = key(m, c); vd.stat.cells++; }
    if (vd.tiles.size) for (let c = 0; c < 768; c++) if (vd.tiles.has(m.vram[NT + c])) { vd.shown[c] = key(m, c); vd.stat.tiles++; }
  }
  vd.cells.clear(); vd.tiles.clear(); vd.all = false;
}
// check: shown против полного пересчёта — первая неверная клетка или -1
function check(m) {
  const vd = m.vd; if (!vd.on) return -1;
  for (let c = 0; c < 768; c++) if (vd.shown[c] !== key(m, c)) return c;
  return -1;
}
module.exports = { init, render, check, key, NT, COL };
