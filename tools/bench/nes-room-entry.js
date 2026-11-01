// Joe must be visible when a room is entered vertically, including on a ladder.
'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
process.chdir(path.resolve(__dirname, '../..'));
const E = require('../vec_emu');
const {symbols} = require('./logic-profile');
const B = process.env.B || 'build/native';
const s = symbols(B);
const m = E.mk(B + '/monty.bin');

for (let frame = 0; frame < 320; frame++) {
  if (frame === 10) m.keyboard.matrix[2] |= 2;
  if (frame === 100) m.keyboard.matrix[2] &= ~2;
  m.frame();
}
assert.deepEqual([m.rd(0x71a7), m.rd(0x71a8)], [0, 10]);

// Insert Joe at the lower border just before the regular boundary handler.
// His room, state and screen are then updated by the game itself.
let injectedDown = false;
m.onInstr = pc => {
  if (pc !== s.L_8DE8 || injectedDown) return;
  injectedDown = true;
  for (const a of [0x7300, 0x7304]) m.wr(a, a === 0x7300 ? 220 : 223);
  for (const a of [0x7301, 0x7305]) m.wr(a, 120);
  m.wr(0x7079, 4); // ladder pose at the first draw in the new room
  m.wr(0x7076, 0);
  m.wr(0x7077, 0);
  m.wr(0x705f, m.rd(0x705f) & ~4);
};
for (let i = 0; i < 80 && m.rd(0x71a7) === 0; i++) m.frame();
assert(injectedDown, 'downward entry was exercised');
assert.deepEqual([m.rd(0x71a7), m.rd(0x71a8)], [1, 10]);
assert.deepEqual([m.rd(0x7300), m.rd(0x7304)], [44, 47], 'upper entry anchors');
m.frame();
assert.equal(m.rd(s.spr_rec), 1, 'Joe is present on the first drawn frame');
assert(m.rd(s.jn_rows_count) >= 15, 'a substantial part of Joe is visible below the HUD');
m.frame();
assert([8, 9].includes(m.rd(s.jn_shown)), 'the ladder pose reaches the screen');
const top = {y: m.rd(0x7304), rows: m.rd(s.jn_rows_count)};

// Ladder, rope and pole poses have different leading rows. All must reach
// the field at the same top-entry anchor, not disappear under the HUD.
for (const pose of [8, 9, 10, 11, 19]) {
  const first = top.y + m.rd(s.joe_top_rows + pose) - (s.joe_nes_rows - 16);
  const visible = Math.min(s.SCREEN_HEIGHT, first + s.joe_nes_rows) - Math.max(s.HUD_ROWS * 8, first);
  assert(visible >= 15, `pose ${pose} visible rows: ${visible}`);
}

// Enter the upper room from below. The original upward offset is preserved;
// check that the sprite is clipped by the screen edge but still visible.
let injectedUp = false;
m.onInstr = pc => {
  if (pc !== s.L_8DE8 || injectedUp || m.rd(0x71a7) !== 1) return;
  injectedUp = true;
  m.wr(0x7300, 27);
  m.wr(0x7304, 30);
  m.wr(0x7301, 120);
  m.wr(0x7305, 120);
  m.wr(0x7079, 4);
  m.wr(0x7076, 0);
  m.wr(0x7077, 0);
};
for (let i = 0; i < 100 && m.rd(0x71a7) === 1; i++) m.frame();
assert(injectedUp, 'upward entry was exercised');
assert.deepEqual([m.rd(0x71a7), m.rd(0x71a8)], [0, 10]);
assert.deepEqual([m.rd(0x7300), m.rd(0x7304)], [219, 222], 'lower entry anchors');
m.frame();
for (let i = 0; i < 80 && m.rd(s.spr_rec) !== 1; i++) m.frame();
assert.equal(m.rd(s.spr_rec), 1, 'Joe is drawn at the lower edge after the room redraw');
assert(m.rd(s.jn_rows_count) >= 15, 'Joe remains visible at the lower edge');
console.log(JSON.stringify({B, top, bottom: {y: m.rd(0x7304), rows: m.rd(s.jn_rows_count)}}));
