#!/usr/bin/env python3
"""Compile the extracted, software-enveloped NES register trace for the 8253.

No ROM or third party modules are needed. Durations are rounded on the 50 Hz
timeline; phrases share complete records, never an unexpanded recording of a tune.
"""
import argparse
import hashlib
import json
import math
from collections import Counter
from pathlib import Path

CPU = 1789773
PIT = 1500000
LENGTH = (10,254,20,2,40,4,80,6,160,8,60,10,14,12,26,14,12,16,24,18,48,20,96,22,192,24,72,26,16,28,32,30)
NOISE = (4,8,16,32,64,96,128,160,202,254,380,508,762,1016,2034,4068)


class Registers:
    """The subset actually used by this soundtrack: constant software volumes.

    Hardware length and triangle linear counters still matter. They run at
    CPU/7457, independently of the game's NTSC frame clock.
    """
    def __init__(self):
        self.r = [0] * 24
        self.length = [0] * 4
        self.linear = 0
        self.reload = False
        self.quarters = 0

    def write(self, address, value):
        self.r[address - 0x4000] = value
        if address in (0x4003, 0x4007, 0x400b, 0x400f):
            channel = (address - 0x4000) // 4
            if self.r[0x15] & (1 << channel):
                self.length[channel] = LENGTH[value >> 3]
            if channel == 2:
                self.reload = True
        elif address == 0x4015:
            for channel in range(4):
                if not value & (1 << channel):
                    self.length[channel] = 0

    def advance(self, time):
        while (self.quarters + 1) * 7457 / CPU <= time:
            self.quarters += 1
            if self.reload:
                self.linear = self.r[8] & 127
            elif self.linear:
                self.linear -= 1
            if not self.r[8] & 128:
                self.reload = False
            if self.quarters % 2 == 0:
                for channel in range(4):
                    if not self.r[channel * 4] & (128 if channel == 2 else 32) and self.length[channel]:
                        self.length[channel] -= 1

    def state(self, threshold, transpositions):
        result = []
        for channel in range(3):
            base = channel * 4
            period = self.r[base + 2] | ((self.r[base + 3] & 7) << 8)
            gate = self.length[channel] and bool(self.r[0x15] & (1 << channel))
            if channel < 2:
                if not self.r[base] & 16:
                    raise ValueError('Hardware pulse envelope is outside this converter profile')
                gate = gate and period >= 8 and (self.r[base] & 15) >= threshold
            else:
                gate = gate and self.linear and period >= 2
            divider = int(PIT * (32 if channel == 2 else 16) * (period + 1) / CPU + 0.5) if gate else 0
            shift = 0
            while divider > 65535:
                divider = (divider + 1) // 2
                shift += 1
            while 0 < divider < 2:
                divider *= 2
                shift -= 1
            if shift:
                transpositions.add((channel, period, shift))
            result.append(divider)
        # Noise is rendered as a short mode-0 pulse, never as a pitched square.
        noise = self.length[3] and (self.r[0x15] & 8) and (self.r[12] & 15) >= threshold
        return (*result, NOISE[self.r[14] & 15] if noise else 0)


def frames(track, frame_period, threshold):
    registers = Registers()
    for address, value in track['initialWrites']:
        registers.write(address, value)
    events = iter(track['events'])
    event = next(events, None)
    states = []
    transpositions = set()
    # Quantise each source write to the nearest Vector frame (at most 10 ms).
    for tick in range(math.ceil(track['frames'] * frame_period * 50)):
        time = (tick + 0.5) / 50
        while event is not None and event[0] * frame_period <= time:
            registers.advance(event[0] * frame_period)
            registers.write(event[1], event[2])
            event = next(events, None)
        registers.advance(time)
        states.append(registers.state(threshold, transpositions))
    return states, sorted(transpositions)


def runs(states):
    result = []
    for state in states:
        if result and state == result[-1][1] and result[-1][0] < 31:
            result[-1] = (result[-1][0] + 1, state)
        else:
            result.append((1, state))
    return result


def phrases(sequences):
    """Flat, nonrecursive shared phrases. An IRQ never follows nested macros."""
    remaining = [list(s) for s in sequences]
    dictionary = []
    while True:
        counts = Counter()
        for seq in remaining:
            for size in range(3, min(64, len(seq)) + 1):
                for start in range(len(seq) - size + 1):
                    candidate = tuple(seq[start:start + size])
                    if not any(isinstance(record, int) for record in candidate) and sum(map(len, candidate)) <= 52:
                        counts[candidate] += 1
        if not counts:
            break
        def saving(candidate):
            return (sum(map(len, candidate)) - 2) * (counts[candidate] - 1) - 3
        best = max(counts, key=lambda c: (saving(c), len(c), c))
        if saving(best) <= 0:
            break
        number = len(dictionary)
        dictionary.append(best)
        for seq in remaining:
            start = 0
            while start <= len(seq) - len(best):
                if tuple(seq[start:start + len(best)]) == best:
                    seq[start:start + len(best)] = [number]
                start += 1
    orders = []
    for seq in remaining:
        order, literal = [], []
        for record in seq + [None]:
            if record is None or isinstance(record, int):
                if literal:
                    order.append(len(dictionary))
                    dictionary.append(tuple(literal))
                    literal = []
                if record is not None:
                    order.append(record)
            else:
                literal.append(record)
                if sum(map(len, literal)) >= 48:
                    order.append(len(dictionary))
                    dictionary.append(tuple(literal))
                    literal = []
        orders.append(order)
    unique, indices = [], {}
    remap = {}
    for i, phrase in enumerate(dictionary):
        if phrase not in indices:
            indices[phrase] = len(unique)
            unique.append(phrase)
        remap[i] = indices[phrase]
    return unique, [[remap[i] for i in order] for order in orders]


def db(values):
    return '\n'.join('\tdb ' + ','.join(map(str, values[i:i + 24])) for i in range(0, len(values), 24)) + '\n'


def emit_block(label, body):
    return label + body if body.startswith('\tEQU') else label + ':\n' + body


def compile_group(tracks, converted, prefix):
    notes = sorted({n for t in tracks for row in converted[t['id']] for n in row[:3]} | {0})
    if len(notes) > 96:
        raise ValueError('Pitch table must fit E840..E8FF')
    sequences = []
    for track in tracks:
        last = (None, None, None)
        seq = []
        for duration, state in runs([row[:3] for row in converted[track['id']]]):
            mask = sum(1 << c for c in range(3) if state[c] != last[c])
            seq.append((duration * 8 + mask, *(64 + 2 * notes.index(state[c]) for c in range(3) if mask & (1 << c))))
            last = state
        sequences.append(seq)
    dictionary, orders = phrases(sequences)
    blocks = []
    for i, phrase in enumerate(dictionary):
        suffixes = [(j, other) for j, other in enumerate(dictionary)
                    if len(other) > len(phrase) and other[-len(phrase):] == phrase]
        if suffixes:
            j, other = min(suffixes, key=lambda pair: (len(pair[1]), pair[0]))
            offset = sum(map(len, other[:-len(phrase)]))
            blocks.append((f'{prefix}_phrase_{i}', f'\tEQU {prefix}_phrase_{j}+{offset}\n', 0))
            continue
        values = [v for record in phrase for v in record] + [0]
        blocks.append((f'{prefix}_phrase_{i}', db(values), len(values)))
    for track, order in zip(tracks, orders):
        values = [f'{prefix}_phrase_{i}' for i in order] + ['0']
        body = ''.join('\tdw ' + ','.join(values[i:i+32]) + '\n' for i in range(0, len(values), 32))
        blocks.append((f"nes_{track['id']}_order", body, 2 * len(values)))
    return notes, blocks, dict(zip((t['id'] for t in tracks), orders)), dictionary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, nargs='?', default=Path('build/nes/music/music.json'))
    parser.add_argument('--output', type=Path, default=Path('src/native/gen'))
    parser.add_argument('--report', type=Path, default=Path('build/nes/music/vi53/conversion.json'))
    parser.add_argument('--threshold', type=int, default=3)
    args = parser.parse_args()
    if not 1 <= args.threshold <= 15:
        parser.error('--threshold must be between 1 and 15')
    data = json.loads(args.input.read_text())
    converted, report = {}, {}
    title_loop = None
    title_lead = 0
    for track in data['tracks']:
        threshold = 1 if track['id'] == 'sfx_landing' else args.threshold
        states, transpositions = frames(track, data['framePeriod'], threshold)
        if track['id'] == 'title':
            title_lead = next(i for i, state in enumerate(states) if any(state[:3]))
            title_loop = states[title_lead:title_lead + round(track['periodFrames'] * data['framePeriod'] * 50)]
        if track['kind'] == 'music':
            states = states[:round(track['periodFrames'] * data['framePeriod'] * 50)]
        converted[track['id']] = states
        report[track['id']] = dict(frames=len(states), seconds=len(states) / 50,
                                  threshold=threshold, transpositions=transpositions,
                                  states=states)
    title = [t for t in data['tracks'] if t['id'] == 'title']
    game = [t for t in data['tracks'] if t['id'] in ('pyramid', 'treasure')]
    notes, blocks, orders, dictionary = compile_group(game, converted, 'game')
    title_notes, title_blocks, title_orders, title_dictionary = compile_group(title, {'title': title_loop}, 'title')
    # The initial silence occurs once. Loop from the first note, carrying the
    # original preceding note into the next cycle rather than replaying silence.
    title_blocks = [(label, '\tdw nes_title_intro\nnes_title_loop_order:\n' + body, size + 2)
                    if label == 'nes_title_order' else (label, body, size)
                    for label, body, size in title_blocks]
    title_blocks.append(('nes_title_intro', db([title_lead * 8 + 7, 64, 64, 64, 0]), 5))
    report['title']['intro_frames'] = title_lead
    report['title']['loop_states'] = title_loop
    # Both pitch tables have the same low address: changing one high-byte operand
    # selects title versus in-game pitches. The title is discarded before tiles.
    high = ['; Generated by tools/nes/music/to_vi53.py.\n\tORG 0xE840\nnes_notes:\n',
            '\tdw ' + ','.join(map(str, notes)) + '\n']
    low = ['; Generated: permanent streams that did not fit E840..EBFF.\n']
    regions = [(0xE840 + 2 * len(notes), 0xEBE0, 'high'),
               (0x0100, 0x01E0, 'boot'), (8, 0x38, 'vectors'),
               (0xFB97, 0xFBD0, 'joe0'), (0xFCC1, 0xFCD0, 'joe1'),
               (0xFD95, 0xFDD0, 'joe2'), (0xFEC0, 0xFED0, 'joe3'),
               (0xEFC8, 0xF000, 'effect_tail')]
    placements = {name: [] for start, end, name in regions}
    cursors = {name: start for start, end, name in regions}
    used = 2 * len(notes)
    sizes = {}
    for label, body, size in sorted(blocks, key=lambda b: (-b[2], b[0])):
        destination = low
        for start, end, name in regions:
            if cursors[name] + size <= end:
                placements[name].append(emit_block(label, body))
                cursors[name] += size
                if name == 'high':
                    used += size
                destination = None
                break
        if destination is low:
            low.append(emit_block(label, body))
        sizes[label] = size
    high.extend(placements['high'])
    high.append('nes_high_end:\n\tASSERT $ <= 0xEBE0\n')
    high.append('\tORG 0xEC40\nnes_title_notes:\n\tdw ' + ','.join(map(str, title_notes)) + '\n')
    title_used = 2 * len(title_notes)
    title_spill = []
    spill_used = 0
    for label, body, size in title_blocks:
        if title_used + size <= 0xF200 - 0xEC40:
            high.append(emit_block(label, body))
            title_used += size
        else:
            title_spill.append(emit_block(label, body))
            spill_used += size
        sizes[label] = size
    high.append('nes_title_end:\n\tASSERT $ <= 0xF200\n\tORG 0xE500\n')
    high.extend(title_spill)
    high.append('nes_title_spill_end:\n\tASSERT $ <= 0xE700\n')
    effects = []
    for track in data['tracks']:
        if track['kind'] != 'sfx' or track['id'] == 'sfx_pole':
            continue
        values = []
        channel = 3 if track['effect_kind'] == 'noise' else 1
        # A newly requested SFX follows the four already published frames. Trim
        # that much of the extraction's initial silent beat, retaining duration
        # with a silent tail. The event's audible onset then stays at NES time.
        source_states = [row[channel] for row in converted[track['id']]]
        lead = next((i for i, value in enumerate(source_states) if value), 0)
        compensated = min(4, lead)
        source_states = source_states[compensated:] + [0] * compensated
        report[track['id']]['queue_compensation_frames'] = compensated
        for duration, state in runs(source_states):
            if channel == 3:
                # Count 256..1024: shorter pulses for landing, longer for death.
                value = min(1024, max(128, state // 2)) if state else 0
            else:
                value = state
            values.extend((duration, value & 255, value >> 8))
        values.append(0)
        effects.append(f"nes_{track['id']}:\n" + db(values))
        report[track['id']]['bytes'] = len(values)
    high.append('\tORG 0xF400\nnes_effect_source:\n\tDISP 0xEF00\n')
    high.extend(effects)
    high.append('\tASSERT $ == 0xEFC8\n')
    high.extend(placements['effect_tail'])
    high.append('nes_effect_end:\n\tASSERT $ <= 0xF000\n\tENT\nnes_effect_source_end:\n')
    source = 0xF400 + sum(t.get('bytes', 0) for t in report.values()) + cursors['effect_tail'] - 0xEFC8
    early, late = [], []
    # Joe tails must be installed after joe_load and before lv_init clears F400.
    # Boot vectors are installed only after the CPU has left boot, from sources
    # above F500 which survive that clearing.
    for start, end, name in sorted(regions[1:], key=lambda r: r[2] in ('boot', 'vectors')):
        size = cursors[name] - start
        if not size or name == 'effect_tail':
            continue
        region_source = 0xF300 if name == 'boot' else 0xF910 if name == 'vectors' else source
        high.append(f'\tORG {region_source}\nnes_reloc_{name}:\n\tDISP {start}\n')
        high.extend(placements[name])
        high.append('\tENT\n')
        target = late if name in ('boot', 'vectors') else early
        target.append(f'\tld de,nes_reloc_{name}\n\tld hl,{start}\n\tld bc,{size}\n\tcall copy_de_hl\n')
        if name not in ('boot', 'vectors'):
            source += size
    if source > 0xF600:
        raise ValueError('Startup relocation sources overlap player code')
    (args.output / 'music_reloc_early.asm').write_text(''.join(early))
    (args.output / 'music_reloc_late.asm').write_text(''.join(late))
    # Procedural pole: no recorded trajectory is emitted.
    report['sfx_pole']['bytes'] = 0
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'music_low.asm').write_text(''.join(low))
    (args.output / 'music.asm').write_text(''.join(high))
    for track in game + title:
        group = title_dictionary if track['id'] == 'title' else dictionary
        order = title_orders[track['id']] if track['id'] == 'title' else orders[track['id']]
        report[track['id']]['stream_bytes_before_suffix_sharing'] = sum(sum(map(len, group[i])) + 1 for i in set(order)) + 2 * (len(order) + 1) + (7 if track['id'] == 'title' else 0)
        report[track['id']]['shared_pitch_table_bytes'] = 2 * len(title_notes if track['id'] == 'title' else notes)
        report[track['id']]['phrases'] = order
    result = dict(format='monty-vi53-v1', input_sha256=hashlib.sha256(args.input.read_bytes()).hexdigest(),
                  rom_sha256=data['rom_sha256'], frame_hz=50, timer_hz=PIT, notes=notes, title_notes=title_notes,
                  high_bytes=used, low_bytes=0,
                  tracks=report)
    result['low_bytes'] = sum(size for label, body, size in blocks) - sum(cursors[name] - start for start, end, name in regions)
    result['relocations'] = {name: cursors[name] - start for start, end, name in regions}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    page_source = []
    for begin, end in [('PS_MORE', '0x7000'), ('joe_band_free_source', 'joe_latch_source'), ('sprite_sources_end', 'joe_high_free_end'),
                       ('ps_heap', 'PS_TOP'), ('ps_boot_source+LIVE_CODE_BYTES', 'ps_boot_source_end'), ('nes_snake_aux_end','sprite_table_free_end'),
                       ('ENEMY_CACHE_FREE','live_hi+256'), ('live_list+LIVE_N','0xFFFF')]:
        for i in range(5):
            page = f'((({begin})&0xFF00)+{256*i})'
            stop = f'({page}+256)'
            page_source.extend([f'\tIF {page} < ({end})', f'\tIF {stop} > ({begin})',
                                f'\tIF {page} < ({begin})', f'\tdw {begin}', '\tELSE',
                                f'\tdw {page}', '\tENDIF', f'\tIF {stop} > ({end})',
                                f'\tdw {end}', '\tELSE', f'\tdw {stop}', '\tENDIF', '\tENDIF', '\tENDIF'])
    (args.output / 'music_pages.asm').write_text('; Generated by to_vi53.py: startup page ranges.\n' + '\n'.join(page_source) + '\n')
    print('Permanent high:', used, 'bytes; stream spill:', result['low_bytes'],
          '; effects:', sum(t.get('bytes', 0) for t in report.values()))


if __name__ == '__main__':
    main()
