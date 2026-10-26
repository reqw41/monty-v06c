// Модель: герой — процесс 88D1. Состояние 7079 (таблица 8913): 0/1 — стоит/идёт, 2 — прыжок, 3 — спуск по
// цепи/верёвке с конвейера, 4 — на лестнице/верёвке, 5/6 — падение, 7 — с верёвки вниз, 8 — гибель (кадры),
// 9 — пауза перед возрождением, A — гибель от падения. Скорость 7076 (dX), 7077 (dY), взгляд 7078,
// высота начала падения/прыжка 707C, точка возрождения 707D-7081 и 704B-7052.
// Ветки состояний переплетены переходами — метки как у оригинала, регистры B, C, E — дословно
// (хвост 8DE8 зависит от B после ветки).
'use strict';
const { rd, wr, rd16, wr16, z } = require('./core');
const V = require('./vdp');
const U = require('./vram');
const S = require('./sound');
const RM = require('./room');
const E = require('./enemy');
const F = require('./frame');
const K = require('./collide');

const b8 = (v) => v & 0xff;
class GameOver extends Error { constructor() { super('конец игры'); } }
const H = module.exports = {
  GameOver,
  // 8B20/8B27: X героя (7301, 7305) := 16 * (X / 16) + (младшая тетрада < 8 ? E : C); CF
  snap(m, r, c, e) { const x = rd(m, 0x7301); if ((x & 0x0f) < 8) c = e; r.a = b8((x & 0xf0) + c); wr(m, 0x7301, r.a); wr(m, 0x7305, r.a); r.cf = 1; },
  '8B20'(m, r) { r.c = 0x0f; r.e = 7; H.snap(m, r, 0x0f, 7); r.c = rd(m, 0x7301) & 0x0f; },
  '8B27'(m, r) { r.c = 0x0c; r.e = 4; H.snap(m, r, 0x0c, 4); r.c = rd(m, 0x7301) & 0x0f; },
  // 8C1F: опрос джойстика; 73EE := (73F0 & C0) | 73EE
  '8C1F'(m, r) { z(m, r, 0x1f76); r.hl = 0x73ee; r.a = (rd(m, 0x73f0) & 0xc0) | rd(m, 0x73ee); wr(m, 0x73ee, r.a); },
  // 8C44: A != 0 — шаг анимации ходьбы (91BD), 705F бит 6 := 0; иначе бит 6 := 1
  '8C44'(m, r) { if (r.a) { K['91BD'](m, r); wr(m, 0x705f, rd(m, 0x705f) & ~0x40); } else wr(m, 0x705f, rd(m, 0x705f) | 0x40); r.hl = 0x705f; },
  '8C3F'(m, r) { r.a = rd(m, 0x73ee) & 5; H['8C44'](m, r); },
  // 8F37: конвейер под ногами (705B в 9412): B += 1 / -1
  '8F37'(m, r) {
    if (rd(m, 0x7079) >= 8) { r.cf = 0; return; }
    const sv = { hl: r.hl, c: r.c }; r.a = rd(m, 0x705b);
    const q = { hl: 0x9412, bc: 7, a: r.a }; K.cpir(m, q);
    if (q.zf) { r.b = b8(r.b + ((q.bc & 0xff) < 4 ? 1 : 0xff)); r.a = r.b; }
    r.hl = sv.hl;
  },
  // 8DC2: жизнь долой
  '8DC2'(m, r) { wr(m, 0x7049, rd(m, 0x7049) - 1); },
  // 8DD4: герой (оба слоя спрайта) += (C по Y, B по X); A := X второго слоя
  '8DD4'(m, r) {
    wr(m, 0x7300, rd(m, 0x7300) + r.c); wr(m, 0x7301, rd(m, 0x7301) + r.b);
    wr(m, 0x7304, rd(m, 0x7304) + r.c); r.a = b8(rd(m, 0x7305) + r.b); wr(m, 0x7305, r.a); r.hl = 0x7305;
  },
  // 8DA2: гибель героя (если ещё не): звук 5, состояние 8, таймер 70A9 = 70h, кадр D4, жизнь; сдвиг на (C, E)
  '8DA2'(m, r) {
    if (rd(m, 0x7079) !== 8) {
      r.a = 5; S.AC1A(m, r); wr(m, 0x7079, 8); wr(m, 0x70a9, 0x70); wr(m, 0x7306, 0xd4); H['8DC2'](m, r);
    }
    r.b = r.e; H['8DD4'](m, r);
  },
  // 8D80: шаг (B, C) со стенами (943C) по направлению B и лазерами (E0, 7000 бит 5 — выкл.)
  '8D80'(m, r) {
    r.a = rd(m, 0x7057);
    if (!(r.b & 0x80)) { wr(m, 0x71b0, rd(m, 0x71b0) + 2); r.a = rd(m, 0x7059); }
    F.A894(m, r);
    if (r.zf) { if (!(r.c & 0x80)) wr(m, 0x7076, 0); r.e = 0; r.b = r.e; return H['8DD4'](m, r); }
    if (rd(m, 0x7058) === 0xe0 && !(rd(m, 0x7000) & 0x20)) return H['8DA2'](m, r);
    r.b = r.e; H['8DD4'](m, r);
  },
  // 8E7E: точка возрождения := текущее состояние; 70B1 бит 4 (8EB0 в кадре)
  '8E7E'(m, r) {
    wr(m, 0x707d, rd(m, 0x7077)); wr(m, 0x707e, rd(m, 0x7076)); wr(m, 0x707f, rd(m, 0x7079)); wr(m, 0x7080, rd(m, 0x7078)); wr(m, 0x7081, rd(m, 0x7075));
    wr(m, 0x707c, rd(m, 0x7300)); for (let i = 0; i < 8; i++) wr(m, 0x704b + i, rd(m, 0x7300 + i));
    r.hl = 0x7308; r.de = 0x7053; r.bc = 0; r.a = rd(m, 0x7075);
    H['8EA8'](m, r);
  },
  '8EA8'(m, r) { wr(m, 0x70b1, rd(m, 0x70b1) | 0x10); },
  // 8E0C: смена комнаты (A — сохранено, BC — сдвиг героя): ниже 9-го ряда — сокровищница или
  // следующий уровень (после сокровищницы, состояние 5); иначе ждать кадр (перерисовка) и запомнить точку
  '8E0C'(m, r) {
    const a0 = r.a;
    if (rd(m, 0x71a7) >= 9) {
      r.a = 1; S.AC1A(m, r);
      if (rd(m, 0x7079) === 5) {
        wr(m, 0x71a7, 0); wr(m, 0x71a8, 8); wr(m, 0x705f, (rd(m, 0x705f) & ~0x28) | 4);
        const sv = { bc: r.bc, hl: r.hl, de: r.de };
        if (rd(m, 0x71a6) < 9) wr(m, 0x71a6, rd(m, 0x71a6) + 1);
        r.hl = 0x70c0; r.bc = 0xc6; K['840B'](m, r); U.A8B7(m, r); r.bc = 0x0700; V['1FD9'](m, r); U.A8C3(m, r);
        r.bc = sv.bc; r.hl = sv.hl; r.de = sv.de;
      } else {
        const f = rd(m, 0x705f); wr(m, 0x705f, f | 0x28);
        if (!(f & 0x20)) { wr(m, 0x70ac, 0xf0); S.AC06(m, r); }
        r.a = a0; H['8DD4'](m, r); return H['8E7E'](m, r);
      }
    }
    r.a = a0; H['8DD4'](m, r); require('./main')['8C13'](m, r); H['8E7E'](m, r);
  },
  // 8DE8: после ветки состояния — шаг (7076, 7077) и выход за край комнаты
  '8DE8'(m, r) {
    r.e = rd(m, 0x7076); r.c = rd(m, 0x7077); H['8D80'](m, r);
    if (r.a >= 4 && r.a < 0xf0) {                       // 8F23: вверх/вниз
      r.bc = 0; r.hl = 0x7304; r.a = rd(m, 0x7304);
      if (r.a < 8) { r.c = 0xa4; r.hl = 0x71a7; r.a = rd(m, 0x705f); if (!(rd(m, 0x705f) & 0x20)) wr(m, 0x71a7, rd(m, 0x71a7) - 1); return H['8E0C'](m, r); }
      if (r.a < 0xac) { r.cf = 1; return; }
      r.c = 0x5c; r.hl = 0x71a7; r.a = rd(m, 0x705f);
      if (rd(m, 0x705f) & 4) { r.hl = 0x71a8; wr(m, 0x71a8, rd(m, 0x71a8) + 1); }
      wr(m, r.hl, rd(m, r.hl) + 1); return H['8E0C'](m, r);
    }
    r.hl = 0x71a8; wr(m, 0x71a8, rd(m, 0x71a8) + 1);    // 8DFA: влево/вправо
    if (r.b & 0x80) { wr(m, 0x71a8, rd(m, 0x71a8) - 2); r.bc = 0xec00; } else r.bc = 0x1600;
    H['8E0C'](m, r);
  },
  // ветка состояния: метки оригинала; 'ret' — возврат в 8910
  state(m, r) {
    const T = [0x8929, 0x8929, 0x8a2f, 0x8c59, 0x8d02, 0x8a83, 0x8a83, 0x8cc5, 0x8b7f, 0x8b8e, 0x8b6e];
    const k = rd(m, 0x7079); if (k > 10) throw new Error('герой: состояние ' + k);
    let L = T[k];
    const joy = () => rd(m, 0x73ee);
    // 8B44: прыжок/падение на верёвку (90/95) — только при dX != 0 и 7072 < 0F, иначе 8C39
    const ok8B44 = () => { r.a = rd(m, 0x7076); if (r.a === 0) return false; r.a = rd(m, 0x7072); return r.a < 0x0f; };
    for (;;) switch (L) {
      case 0x8929:
        if (rd(m, 0x705b) === 8 && rd(m, 0x7058) === 8) { r.bc = 0xf800; if (rd(m, 0x7057)) r.b = 8; H['8DD4'](m, r); return; }
        r.a = rd(m, 0x7057); K['913B'](m, r); if (r.zf) { L = 0x8a91; break; }
        r.a = joy() & 0x0f; H['8C44'](m, r); wr(m, 0x7077, 0); r.bc = 0;
        if (joy() & 1) { if (rd(m, 0x7058) === 0x88 && rd(m, 0x7059) === 0x89) { H['8B20'](m, r); r.c = 0xfc; L = 0x8986; break; } }
        if (joy() & 4) {
          r.a = rd(m, 0x705b); if (r.a === 0x10) { r.a = rd(m, 0x705c); if (r.a === 0x11) { L = 0x897c; break; } }
          if (r.a === 0xc4) { H['8B27'](m, r); wr(m, 0x705f, rd(m, 0x705f) | 0x40); r.a = 4; L = 0x8988; break; }
        }
        if (joy() & 8) { r.bc = 0xfe00; K['90E3'](m, r); L = r.cf ? 0x89dc : 0x89f6; break; }
        if (joy() & 2) { r.bc = 0x0200; K['90E3'](m, r); L = r.cf ? 0x89dc : 0x89f6; break; }
        r.bc = 0; K['90E3'](m, r); if (r.cf) { L = 0x89dc; break; }
        { const bc = r.bc; K['911E'](m, r); r.bc = bc; }
        if (!r.cf) { r.a = 0; r.bc = 0; L = 0x8992; break; }
        L = 0x8a01; break;
      case 0x897c: H['8B20'](m, r); r.c = 2; wr(m, 0x70b2, 8); L = 0x8986; break;
      case 0x8986: r.a = 3; L = 0x8988; break;
      case 0x8988: if (r.b) wr(m, 0x7078, r.b); L = 0x8992; break;
      case 0x8992:
        wr(m, 0x7079, r.a);
        if (r.a !== 2 && (rd(m, 0x70ab) & 1) !== 1) H['8F37'](m, r);
        wr(m, 0x7076, r.b); wr(m, 0x7077, r.c); r.hl = 0x7077; return;
      case 0x89dc:
        r.a = 7; S.AC1A(m, r); wr(m, 0x707c, rd(m, 0x7300)); wr(m, 0x7072, 0x12); r.hl = 0x93ae; r.c = 0xff; r.a = 2; L = 0x8988; break;
      case 0x89f6: { const bc = r.bc; K['911E'](m, r); r.bc = bc; }
        if (r.cf) { L = 0x8a01; break; } r.a = 1; L = 0x8988; break;
      case 0x8a01: wr(m, 0x707c, rd(m, 0x7300)); r.a = 6; L = 0x8988; break;
      case 0x8a2f: {                                     // прыжок
        r.d = 4;
        const t = rd(m, 0x7072); if (t) { wr(m, 0x7072, t - 1); r.a = t - 1; r.hl = 0x93ae; RM.A540(m, r); r.d = rd(m, r.hl); }
        r.a = rd(m, 0x7076); if (r.a) wr(m, 0x7078, r.a);
        r.b = r.a; r.c = r.d;
        r.a = rd(m, 0x7058);
        if (r.a === 0x90) { L = 0x8b0e; break; }
        if (r.a === 0x95 && rd(m, 0x705b) !== 8) { L = 0x8b5b; break; }
        r.a = rd(m, rd(m, 0x7076) & 0x80 ? 0x7059 : 0x7057); if (r.a === 8) wr(m, 0x7076, 0);
        if (rd(m, 0x7077) & 0x80) { L = 0x8c39; break; }
        L = 0x8a86; break;
      }
      case 0x8a83: r.bc = 4; L = 0x8a86; break;           // падение
      case 0x8a86: { const bc = r.bc; K['911E'](m, r); r.bc = bc; }
        if (r.cf) { L = 0x8b06; break; }
        if (r.a === 0xd2) { L = 0x8a91; break; }
        r.c = 0; r.a = rd(m, 0x7300);
        for (;;) { r.a &= 0x0f; if (r.a === 4 || r.a === 0x0c) break; r.a = b8(r.a - 1); r.c = b8(r.c - 1); }
        { const bc = r.bc; r.a = 4; S.AC1A(m, r);
          if (rd(m, 0x71a8) === 0x0a && (rd(m, 0x705f) & 4)) { wr(m, 0x705f, rd(m, 0x705f) & ~4); H['8E7E'](m, r); }
          const y0 = rd(m, 0x707c), y = rd(m, 0x7300); r.bc = bc;
          if (y < y0 || b8(y - y0) < 0x1c || rd(m, 0x7079) === 5) { r.a = 1; L = 0x8992; break; }
          wr(m, 0x7300, rd(m, 0x7304)); wr(m, 0x7304, y); r.a = 9; L = 0x8af0; break; }
      case 0x8a91: r.a = 5; S.AC1A(m, r); r.a = 0x0a; L = 0x8af0; break;
      case 0x8af0: { const a = r.a; H['8DC2'](m, r); wr(m, 0x70a9, 0x70); r.a = a; r.bc = 0; L = 0x8988; break; }
      case 0x8b06: r.a = rd(m, 0x705b); if (r.a !== 0x90) { L = 0x8b57; break; } L = 0x8b0e; break;
      case 0x8b0e: if (!ok8B44()) { L = 0x8c39; break; }
        { const bc = r.bc; H['8B27'](m, r); r.bc = bc; } r.a = 4; r.bc = 0; L = 0x8992; break;
      case 0x8b57: if (r.a !== 0x95) { L = 0x8c39; break; } L = 0x8b5b; break;
      case 0x8b5b: if (!ok8B44()) { L = 0x8c39; break; }
        H['8B27'](m, r); r.bc = 4; r.a = 6; S.AC1A(m, r); r.a = 5; L = 0x8992; break;
      case 0x8b6e: wr(m, 0x7300, rd(m, 0x7300) - 1); wr(m, 0x7302, 0x78); wr(m, 0x7303, 0x0e); wr(m, 0x7307, 0); L = 0x8b8e; break;
      case 0x8b7f: r.a = rd(m, 0x70a9); if (!(r.a & 4)) { r.a &= 3; r.hl = 0x93a6; K['9305'](m, r); } L = 0x8b8e; break;
      case 0x8b8e: {
        const t = b8(rd(m, 0x70a9) - 1); wr(m, 0x70a9, t);
        if (!(t & 0x80)) { r.bc = 0; L = 0x8c39; break; }
        if (!rd(m, 0x7049)) {                            // 8B9D: конец игры — надпись, дальше ждать огня
          wr(m, 0x7049, 6); wr(m, 0x7303, 0); wr(m, 0x7307, 0); S['1FD6'](m, r);
          for (let i = 0; i < 3; i++) wr(m, 0x70bd + i, 0);
          r.bc = 0x0109; r.hl = 0x9409; r.de = 0x016c; U.AEA7(m, r);
          throw new H.GameOver();                        // ожидание огня и перезапуск (8BBE..8BDE) — у порта своё
        }
        wr(m, 0x7303, 6); wr(m, 0x7307, 0x0b);
        wr(m, 0x7077, rd(m, 0x707d)); wr(m, 0x7076, rd(m, 0x707e)); wr(m, 0x7079, rd(m, 0x707f)); wr(m, 0x7078, rd(m, 0x7080)); wr(m, 0x7075, rd(m, 0x7081));
        for (let i = 0; i < 8; i++) wr(m, 0x7300 + i, rd(m, 0x704b + i));
        r.a = rd(m, 0x7081); require('./vram')['9156'](m, r); require('./main')['8C13'](m, r); return;
      }
      case 0x8c36: r.bc = 0; L = 0x8c39; break;
      case 0x8c39: r.a = rd(m, 0x7079); L = 0x8992; break;
      case 0x8c59: {                                     // 3
        r.a = rd(m, 0x70b2); r.b = r.a;
        if (r.a & 0x0f) {
          r.b = b8(r.b - 1); r.a = r.b; wr(m, 0x70b2, r.b);
          if (r.b & 2) { L = 0x8c36; break; }
          r.bc = r.a & 0x80 ? 0x00fe : 0x0002; L = 0x8c39; break;
        }
        if (r.b & 0x80) { r.bc = 0; L = 0x8a01; break; }
        r.bc = 0; H['8C3F'](m, r); L = 0x8c87; break;
      }
      case 0x8c87: r.a = rd(m, 0x705b); K['9122'](m, r); if (!r.cf) { L = 0x8a01; break; }
        if (!(joy() & 4)) { L = 0x8cd1; break; } r.bc = 1; L = 0x8c39; break;
      case 0x8c9c:
        if (rd(m, 0x705f) & 0x20) { L = joy() & 1 ? 0x8c36 : 0x8d55; break; }
        L = joy() & 1 ? 0x8cc5 : 0x8cd1; break;
      case 0x8cc5: r.bc = 0; wr(m, 0x707c, rd(m, 0x7300)); L = 0x8a01; break;
      case 0x8cd1:
        if (joy() & 1) { r.bc = 0x00ff; if (rd(m, 0x7079) === 4 && !(rd(m, 0x70ab) & 1)) r.c = 0; L = 0x8c39; break; }
        r.bc = 1; if (!(joy() & 4)) { L = 0x8c36; break; }
        K['911E'](m, r); L = r.cf ? 0x8a01 : 0x8c39; break;
      case 0x8d02:                                       // 4
        H['8C3F'](m, r); K['90E3'](m, r); if (!r.cf) { L = 0x8d4a; break; }
        if (joy() & 8) { r.bc = 0xfe00; L = 0x8d14; break; }
        if (joy() & 2) { r.bc = 0x0200; L = 0x8d14; break; }
        L = 0x8d4a; break;
      case 0x8d14:
        if ((rd(m, 0x705f) & 0x20) && rd(m, 0x70ac) === 1) { wr(m, 0x705f, rd(m, 0x705f) | 8); r.b = r.b & 0x80 ? 0xfc : 4; }
        L = 0x89dc; break;
      case 0x8d3e: if (joy() & 1) r.c = 0xfe; L = 0x8c39; break;
      case 0x8d4a: r.bc = 0; if (rd(m, 0x7058) === 0) { L = 0x8c9c; break; } L = 0x8d55; break;
      case 0x8d55: r.a = rd(m, 0x705b); if (r.a === 0xd8 || r.a === 0x98 || r.a === 0) { L = 0x8d65; break; } L = 0x8c87; break;
      case 0x8d65: if (rd(m, 0x705f) & 0x20) { L = 0x8d3e; break; }
        r.bc = 0; wr(m, 0x707c, 0xa0); r.a = 6; L = 0x8988; break;
      default: throw new Error('герой: метка ' + L.toString(16));
    }
  },
  // 88D1 (процесс): кадр, такт 70AB, враги, ввод (во вступлении — сам идёт), ветка состояния, шаг
  '88D1'(m, r) {
    K['92DC'](m, r);
    let a = b8(rd(m, 0x70ab) - 1); if (a & 0x80) a = 3; wr(m, 0x70ab, a);
    E.A7A1(m, r); H['8C1F'](m, r);
    if (rd(m, 0x705f) & 4) wr(m, 0x73ee, rd(m, 0x7301) < 0x80 ? 0x86 : 0x8c);
    require('./vram')['9156'](m, r);
    H.state(m, r); H['8DE8'](m, r);
  },
};
