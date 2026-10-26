#!/usr/bin/env python3
"""Перевод картриджа Coleco (8000-BFFF, разметка build/monty.skool) в ассемблер i8080 (синтаксис Z80 для
sjasmplus --i8080) с символическими ссылками.

  tools/z2i.py  -> src/vec/gen/game.asm, src/vec/gen/zhelp.asm, build/vec/z2i_report.txt

Правила:
- метки: L_xxxx — команды, D_xxxx — байты данных (только те, на которые есть ссылки);
- вызовы OS7 (1F61-1FFF) -> os7_<ИМЯ>, вызовы и переходы в прослойку MSX (2000-25AE) -> ad_<адрес>;
- числа 8000-BFFF в операндах LD/… — адреса картриджа (метки), кроме CONSTS; 7000-73FF — ОЗУ игры, на Векторе
  по тем же адресам; прочие числа — как есть;
- таблицы указателей: PTR_TABLES и встроенные записи AE00 (W в разметке) — dw <метка>;
- команды без аналога в i8080: JR -> JP, DJNZ -> DEC B / JP NZ, LDIR/CPIR/NEG/SBC HL/EX AF/EXX — вызовы
  z_*, BIT/SET/RES — вставки с сохранением A (SET/RES — и флагов), сдвиги CB — вызовы z_<оп>_<рег> с флагами
  как у Z80 (S, Z, P по результату, CY), IX/IY — ячейки z_ix/z_iy; адреса из MANUAL — вставки руками
  (src/vec/manual/<адрес>.asm), предупреждения — в отчёт.
"""
import re, os, sys
ROOT = os.path.join(os.path.dirname(__file__), '..')
IMG = open(os.path.join(ROOT, 'build/monty_entry.bin'), 'rb').read()
LO, HI = 0x800C, 0xBFFF            # 8000-800B — заголовок Coleco, не нужен

PTR_TABLES = {0x8913: 11, 0xA20A: 8, 0x9477: 100, 0xAD0B: 10}
PTR_WORDS = {0xA8A3, 0xA8A8, 0xA8AD, 0xA8B2}   # таблица процессов A8A1: [счётчик, процедура, перезагрузка] x4 (A5D8)
CONSTS = {0x8282}                   # адреса команд, у которых число 8000-BFFF — не адрес (8282: сигнатура AA55)
MANUAL = {0xAE46: 0xAE4F}           # адрес начала: адрес конца (не включая) — вставка руками src/vec/manual/
OS7 = {}
for l in open(os.path.join(ROOT, 'src/monty.ctl')):
    m = re.match(r'@ \$([0-9A-F]{4}) label=(\w+)', l)
    if m and 0x1F61 <= int(m.group(1), 16) <= 0x1FFF: OS7[int(m.group(1), 16)] = m.group(2)

# --- разбор skool -----------------------------------------------------------------------------------------
items = []                          # ('c', адрес, текст) | ('b', адрес, длина)
ptr_words = set()                   # адреса слов-указателей в данных
for a, n in PTR_TABLES.items():
    for k in range(n): ptr_words.add(a + 2 * k)
ptr_words |= PTR_WORDS
kind = None
for l in open(os.path.join(ROOT, 'build/monty.skool')):
    m = re.match(r'^([cbw* @])\$([0-9A-F]{4}) (.*?)\s*(;.*)?$', l)
    if not m: continue
    t, a, txt = m.group(1), int(m.group(2), 16), m.group(3).strip()
    if t in 'cbw': kind = t
    if not (LO <= a <= HI): continue
    if kind == 'c': items.append(('c', a, txt))
    else:
        if txt.startswith('DEFW') and kind == 'b':
            # слово DEFW внутри b — встроенные параметры AE00 (W в разметке) -> указатель
            cnt = len(txt[4:].split(','))
            for k in range(cnt): ptr_words.add(a + 2 * k)
        items.append(('b', a, None))
# длины данных: от адреса до следующего элемента
addrs = [a for _, a, _ in items]
code = {a for k, a, _ in items if k == 'c'}
datab = set()
for i, (k, a, _) in enumerate(items):
    if k == 'b':
        e = items[i + 1][1] if i + 1 < len(items) else HI + 1
        datab.update(range(a, e))

warn, refs, labels = [], set(), {0x8195, 0x8413, 0xA9B3, 0x8025}   # метки для платформенного слоя


def ref(v, at):
    """адрес картриджа -> метка (с поправкой внутри данных)"""
    if v in code: labels.add(v); return f'L_{v:04X}'
    if v in datab: labels.add(v); return f'D_{v:04X}'
    if v == HI + 1: return 'cart_end'
    warn.append(f'{at:04X}: ссылка {v:04X} внутрь команды или вне картриджа'); return f'0x{v:04X}'


def target(v, at):
    if 0x1F61 <= v <= 0x1FFF and v in OS7: return 'os7_' + OS7[v]
    if 0x2000 <= v < 0x25AF: return f'ad_{v:04X}'
    if LO <= v <= HI: return ref(v, at)
    warn.append(f'{at:04X}: переход в {v:04X}'); return f'os7_{v:04X}'


R8 = {'A', 'B', 'C', 'D', 'E', 'H', 'L', '(HL)'}
CC = {'NZ', 'Z', 'NC', 'C', 'PO', 'PE', 'P', 'M'}
helpers = set()


def num(s):
    m = re.fullmatch(r'\$([0-9A-F]+)', s)
    return int(m.group(1), 16) if m else None


def operand(s, at, branch=False):
    """подстановка чисел в операнде"""
    def sub(m):
        v = int(m.group(1), 16)
        if len(m.group(1)) == 4:
            if branch: return target(v, at)
            if LO <= v <= HI and at not in CONSTS: return ref(v, at)
        return f'0x{v:0{len(m.group(1))}X}'
    return re.sub(r'\$([0-9A-F]+)', sub, s)


def tr(a, txt, nxt):
    """одна команда Z80 -> список строк i8080"""
    m = re.match(r'(\w+)\s*(.*)', txt)
    op, args = m.group(1), m.group(2)
    A = [x.strip() for x in args.split(',')] if args else []
    lo = lambda s: s.lower()
    if op in ('JR', 'JP', 'CALL'):
        if len(A) == 2: return [f'{"jp" if op == "JR" else lo(op)}\t{lo(A[0])},{operand(A[1], a, True)}']
        if A[0] in ('(HL)',): return ['jp\t(hl)']
        if A[0].startswith('(I'): warn.append(f'{a:04X}: {txt}'); return [f'; !!! {txt}']
        return [f'{"jp" if op == "JR" else lo(op)}\t{operand(A[0], a, True)}']
    if op == 'DJNZ':
        return ['dec\tb', f'jp\tnz,{operand(A[0], a, True)}']
    if op in ('RET',) and A and A[0] in ('PE', 'PO'): warn.append(f'{a:04X}: {txt} (чётность вместо переполнения)')
    if op in ('RETN', 'RETI'): return ['ret']
    if op in ('LDIR', 'LDDR', 'CPIR', 'NEG', 'EXX'):
        helpers.add(op.lower()); return [f'call\tz_{op.lower()}']
    if op == 'EX' and A[0] == 'AF': helpers.add('exaf'); return ['call\tz_exaf']
    if op in ('ADC', 'SBC') and A[0] == 'HL':
        h = f'{op.lower()}_hl_{A[1].lower()}'; helpers.add(h); return [f'call\tz_{h}']
    if op == 'BIT':
        n, r = int(A[0]), A[1]
        if 'I' in r: warn.append(f'{a:04X}: {txt}'); return [f'; !!! {txt}']
        mk = 1 << n
        chk_carry(a, nxt, txt)
        if r == 'A': return ['ld\t(z_t),a', f'and\t0x{mk:02X}', 'ld\ta,(z_t)']
        return ['ld\t(z_t),a', f'ld\ta,{lo(r)}', f'and\t0x{mk:02X}', 'ld\ta,(z_t)']
    if op in ('SET', 'RES'):
        n, r = int(A[0]), A[1]
        if 'I' in r: warn.append(f'{a:04X}: {txt}'); return [f'; !!! {txt}']
        f = f'or\t0x{1 << n:02X}' if op == 'SET' else f'and\t0x{0xFF ^ (1 << n):02X}'
        if r == 'A': return ['push\tbc', 'push\taf', 'pop\tbc', 'ld\ta,b', f, 'ld\tb,a', 'push\tbc', 'pop\taf', 'pop\tbc']
        return ['push\taf', f'ld\ta,{lo(r)}', f, f'ld\t{lo(r)},a', 'pop\taf']
    if op in ('SLA', 'SRA', 'SRL', 'RL', 'RR', 'RLC', 'RRC', 'SLL'):
        r = A[0]
        if 'I' in r: warn.append(f'{a:04X}: {txt}'); return [f'; !!! {txt}']
        rn = 'mhl' if r == '(HL)' else r.lower()
        h = f'{op.lower()}_{rn}'; helpers.add(h); return [f'call\tz_{h}']
    if 0xAF70 <= a <= 0xAFC7 and any('(IY+' in x for x in A):   # начисление очков: IY = 7017 (счёт BCD)
        A = [re.sub(r'\(IY\+\$([0-9A-F]+)\)', lambda m: f'(0x{0x7017 + int(m.group(1), 16):04X})', x) for x in A]
        if op == 'LD': return [f'ld\t{lo(A[0])},{lo(A[1])}' if A[1] == 'A' else f'ld\ta,{A[1]}']
        mm = re.match(r'\((0x[0-9A-F]+)\)', A[1])
        return ['push\thl', f'ld\thl,{mm.group(1)}', f'{lo(op)}\ta,(hl)', 'pop\thl']
    if any('IX' in x or 'IY' in x for x in A):
        if op == 'LD' and A[0] in ('IX', 'IY') and not A[1].startswith('('):
            return ['push\thl', f'ld\thl,{operand(A[1], a)}', f'ld\t(z_{A[0].lower()}),hl', 'pop\thl']
        if op == 'PUSH': return ['push\thl', f'ld\thl,(z_{A[0].lower()})', 'ex\t(sp),hl']
        if op == 'POP': return ['ex\t(sp),hl', f'ld\t(z_{A[0].lower()}),hl', 'pop\thl']
        if op == 'INC' and len(A) == 1: return ['push\thl', f'ld\thl,(z_{A[0].lower()})', 'inc\thl', f'ld\t(z_{A[0].lower()}),hl', 'pop\thl']
        warn.append(f'{a:04X}: {txt} — нужна ручная вставка'); return [f'; !!! {txt}']
    if op == 'LD' and len(A) == 2:
        d, s = A
        if d in ('BC', 'DE', 'SP') and s.startswith('('):
            nn = operand(s[1:-1], a)
            if d == 'DE': return ['ex\tde,hl', f'ld\thl,({nn})', 'ex\tde,hl']
            if d == 'BC': return ['push\thl', f'ld\thl,({nn})', 'ld\tb,h', 'ld\tc,l', 'pop\thl']
            warn.append(f'{a:04X}: {txt}'); return [f'; !!! {txt}']
        if s in ('BC', 'DE', 'SP') and d.startswith('('):
            nn = operand(d[1:-1], a)
            if s == 'DE': return ['ex\tde,hl', f'ld\t({nn}),hl', 'ex\tde,hl']
            if s == 'BC': return ['push\thl', 'ld\th,b', 'ld\tl,c', f'ld\t({nn}),hl', 'pop\thl']
            warn.append(f'{a:04X}: {txt}'); return [f'; !!! {txt}']
        if s in ('I', 'R') or d in ('I', 'R'): warn.append(f'{a:04X}: {txt}'); return [f'; !!! {txt}']
        if d.startswith('(') and s == 'A' and d not in ('(HL)', '(BC)', '(DE)'):
            v = num(d[1:-1])
            if v is not None and LO <= v <= HI: warn.append(f'{a:04X}: запись в картридж {txt}')
    if op in ('IN', 'OUT', 'IM', 'HALT'):
        warn.append(f'{a:04X}: {txt}')
    if op in ('JP',) or op.startswith('J'): pass
    if op in ('ADC', 'SBC', 'ADD', 'SUB', 'AND', 'OR', 'XOR', 'CP') and len(A) == 2 and A[0] == 'A' and op not in ('ADD', 'ADC', 'SBC'):
        A = A[1:]                                   # «SUB A,n» -> «sub n» не встречается, на всякий случай
    if op == 'DAA': pass
    return [f'{lo(op)}\t' + ','.join(operand(x, a) if '$' in x else lo(x) for x in A) if A else lo(op)]


def chk_carry(a, nxt, txt):
    if nxt and re.match(r'(JR|JP|CALL|RET) N?C\b|ADC|SBC|RLA|RRA|RL |RR ', nxt):
        warn.append(f'{a:04X}: {txt} — дальше используется CY (у i8080 AND сбрасывает CY)')


# --- вывод -----------------------------------------------------------------------------------------------
out = ['; создано tools/z2i.py из build/monty.skool — не править', '']
body = []
i = 0
while i < len(items):
    k, a, txt = items[i]
    if a in MANUAL:
        labels.add(a); body.append(('raw', f'L_{a:04X}:\t\t\t\t; {a:04X}-{MANUAL[a] - 1:04X} вручную')); body.append(('raw', f'\t\tINCLUDE\t"manual/{a:04X}.asm"'))
        e = MANUAL[a]
        while i < len(items) and items[i][1] < e: i += 1
        continue
    if k == 'c':
        nxt = items[i + 1][2] if i + 1 < len(items) and items[i + 1][0] == 'c' else None
        body.append(('lab', a))
        body.append(('ins', a, txt, tr(a, txt, nxt)))
        if txt.startswith('DJNZ') and nxt and re.match(r'(JR|JP|CALL|RET) N?Z|ADC|SBC', nxt or ''):
            warn.append(f'{a:04X}: DJNZ, дальше флаги ({nxt}) — у i8080 DEC B меняет флаги')
        i += 1
    else:                           # подряд идущие строки данных — один блок (слово может стоять на стыке строк)
        j = i + 1
        while j < len(items) and items[j][0] == 'b' and items[j][1] not in MANUAL: j += 1
        e = items[j][1] if j < len(items) else HI + 1
        body.append(('data', a, e)); i = j

for b in body:                      # предварительно: метки целей указателей в данных
    if b[0] == 'data':
        for p in range(b[1], b[2]):
            if p in ptr_words and p + 1 < b[2]:
                w = IMG[p] | IMG[p + 1] << 8
                if LO <= w <= HI: ref(w, p)
for b in body:
    if b[0] == 'lab':
        pass
    elif b[0] == 'raw': out.append(b[1])
    elif b[0] == 'ins':
        _, a, txt, lines = b
        if a in labels: out.append(f'L_{a:04X}:')
        out.append(f'\t\t{lines[0]}\t\t; {a:04X} {txt}')
        for x in lines[1:]: out.append(f'\t\t{x}')
    else:
        _, a, e = b
        p = a; row = []
        def flush():
            if row: out.append('\t\tdb\t' + ','.join(row)); row.clear()
        while p < e:
            if p in labels: flush(); out.append(f'D_{p:04X}:')
            if p in ptr_words and p + 1 < e:
                flush(); w = IMG[p] | IMG[p + 1] << 8
                if LO <= w <= HI: out.append(f'\t\tdw\t{ref(w, p)}')
                elif w < 0x2000 and w: out.append(f'\t\tdw\tos7rom+0x{w:04X}'); warn.append(f'{p:04X}: указатель в ПЗУ OS7 {w:04X}')
                else: out.append(f'\t\tdw\t0x{w:04X}')
                p += 2; continue
            row.append(f'0x{IMG[p]:02X}'); p += 1
            if len(row) == 16: flush()
        flush()
out.append('cart_end:')
os.makedirs(os.path.join(ROOT, 'src/vec/gen'), exist_ok=True)
open(os.path.join(ROOT, 'src/vec/gen/game.asm'), 'w').write('\n'.join(out) + '\n')
os.makedirs(os.path.join(ROOT, 'build/vec'), exist_ok=True)
open(os.path.join(ROOT, 'build/vec/z2i_report.txt'), 'w').write('\n'.join(warn) + '\n')
open(os.path.join(ROOT, 'build/vec/z2i_helpers.txt'), 'w').write('\n'.join(sorted(helpers)) + '\n')
print('команд', sum(1 for b in body if b[0] == 'ins'), 'предупреждений', len(warn), 'вспомогательных', len(helpers))

# --- вспомогательные процедуры (src/vec/gen/zhelp.asm) ------------------------------------------------
H = ['; создано tools/z2i.py — вспомогательные процедуры для команд Z80 без аналога в i8080', '']
H += ['z_ldir:\t\tpush\taf\t\t\t; LDIR: флаги S, Z, C и A сохраняются', 'zl1:\t\tld\ta,(hl)', '\t\tld\t(de),a', '\t\tinc\thl', '\t\tinc\tde',
      '\t\tdec\tbc', '\t\tld\ta,b', '\t\tor\tc', '\t\tjp\tnz,zl1', '\t\tpop\taf', '\t\tret', '']
H += ['z_cpir:\t\tpush\tde\t\t\t; CPIR: Z = найдено (CY не сохраняется)', '\t\tld\td,a', 'zc1:\t\tld\ta,(hl)', '\t\tinc\thl', '\t\tdec\tbc', '\t\tcp\td',
      '\t\tjp\tz,zc2', '\t\tld\ta,b', '\t\tor\tc', '\t\tjp\tnz,zc1', '\t\tld\ta,1', '\t\tor\ta', '\t\tld\ta,d', '\t\tpop\tde', '\t\tret',
      'zc2:\t\tld\ta,d', '\t\tcp\td', '\t\tpop\tde', '\t\tret', '']
H += ['z_exaf:\t\tpush\thl\t\t\t; EX AF,AF\': обмен с z_af2', '\t\tpush\taf', '\t\tld\thl,(z_af2)', '\t\tex\t(sp),hl', '\t\tld\t(z_af2),hl',
      '\t\tpop\taf', '\t\tpop\thl', '\t\tret', '']
H += ['z_exx:\t\tpush\thl\t\t\t; EXX: обмен BC, DE, HL с z_bc2, z_de2, z_hl2 (флаги не меняются)', '\t\tld\thl,(z_hl2)', '\t\tex\t(sp),hl',
      '\t\tld\t(z_hl2),hl', '\t\tpop\thl', '\t\tex\tde,hl', '\t\tpush\thl', '\t\tld\thl,(z_de2)', '\t\tex\t(sp),hl', '\t\tld\t(z_de2),hl',
      '\t\tpop\thl', '\t\tex\tde,hl', '\t\tpush\thl', '\t\tld\th,b', '\t\tld\tl,c', '\t\tpush\thl', '\t\tld\thl,(z_bc2)', '\t\tld\tb,h',
      '\t\tld\tc,l', '\t\tpop\thl', '\t\tld\t(z_bc2),hl', '\t\tpop\thl', '\t\tret', '']
H += ['z_neg:\t\tcpl\t\t\t\t; NEG: CY = (A != 0)', '\t\tinc\ta', '\t\tscf', '\t\tret\tnz', '\t\tccf', '\t\tret', '']
H += ['z_sbc_hl_bc:\tld\t(z_t),a\t\t\t; SBC HL,BC: CY — заём, Z — HL = 0 (S не точен), A сохраняется', '\t\tld\ta,l', '\t\tsbc\ta,c', '\t\tld\tl,a',
      '\t\tld\ta,h', '\t\tsbc\ta,b', '\t\tld\th,a', '\t\tjp\tc,zsb1', '\t\tld\ta,h', '\t\tor\tl', '\t\tld\ta,(z_t)', '\t\tret',
      'zsb1:\t\tld\ta,h', '\t\tor\tl', '\t\tscf', '\t\tld\ta,(z_t)', '\t\tret', '']
OPS = {'sla': ['add\ta,a'], 'srl': ['or\ta', 'rra'], 'sra': ['push\tbc', 'ld\tb,a', 'rlca', 'ld\ta,b', 'rra', 'pop\tbc'],
       'rl': ['rla'], 'rr': ['rra'], 'rlc': ['rlca'], 'rrc': ['rrca']}
for h in sorted(helpers):
    m = re.fullmatch(r'(sla|srl|sra|rl|rr|rlc|rrc)_(\w+)', h)
    if not m: continue
    o, r = m.groups()
    reg = '(hl)' if r == 'mhl' else r
    H.append(f'z_{h}:\t\t\t\t\t; {o.upper()} {reg.upper()}: S, Z, P по результату, CY — выдвинутый бит')
    if reg != 'a': H += ['\t\tld\t(z_t),a', f'\t\tld\ta,{reg}']
    H += ['\t\t' + x for x in OPS[o]]
    if o == 'sla':
        if reg != 'a': H += [f'\t\tld\t{reg},a', '\t\tld\ta,(z_t)']
        H += ['\t\tret', '']; continue
    tail = [] if reg == 'a' else [f'\t\tld\t{reg},a', '\t\tld\ta,(z_t)']
    H += [f'\t\tjp\tc,z_{h}_c', '\t\tor\ta'] + tail + ['\t\tret', f'z_{h}_c:\tor\ta', '\t\tscf'] + tail + ['\t\tret', '']
open(os.path.join(ROOT, 'src/vec/gen/zhelp.asm'), 'w').write('\n'.join(H) + '\n')
