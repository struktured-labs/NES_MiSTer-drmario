#!/usr/bin/env python3
"""Firmware-in-image proof by perfect bijection.

The 16KBx8 copro ROM is fitted as 16 one-bit-wide 8192-entry BRAM slices
(8 bit-lanes x 2 address halves).  For each physical block we reconstruct its
8192-bit init vector from the post-fit simulation netlist (quartus_eda --simulation,
generated FROM THE SAME COMPILED DB the assembler serialized into NES.sof/NES.rbf).
Proof: there is a PERFECT BIJECTION between the 16 physical vectors and the 16
reference slices computed from a firmware hex.  8192 bits must match exactly per
pairing; an accidental match is ~2^-8192.

Killed-mutant controls: th150 (2 dose bytes differ -> exactly 3 low-half lane
slices must fail), preship f4b6dfbf (broadly different -> many slices fail).
"""
import re
import sys

VO = sys.argv[1]
CANDIDATES = sys.argv[2:]
SIZE = 16384
HALF = 8192

text = open(VO).read()
defp = {}
for m in re.finditer(r'defparam\s+(\S+)\s*\.\s*(\w+)\s*=\s*("(?:[^"]*)"|[^;]+);', text):
    inst, param, val = m.group(1), m.group(2), m.group(3).strip()
    if val.startswith('"'):
        val = val[1:-1]
    defp.setdefault(inst, {})[param] = val

blocks = {k: v for k, v in defp.items()
          if 'copro2|rom_rtl_0' in k and any(p.startswith('mem_init') for p in v)}
assert len(blocks) == 16, "expected 16 ROM blocks, got %d" % len(blocks)

def block_bits(v):
    inits = sorted((p for p in v if re.fullmatch(r'mem_init\d+', p)), key=lambda p: int(p[8:]))
    blob = ''.join(v[p] for p in reversed(inits))  # mem_initN = most significant chunk
    bv = int(blob, 16) if blob else 0
    n = int(v['port_a_last_address']) - int(v['port_a_first_address']) + 1
    assert n == HALF and int(v['port_a_data_width']) == 1
    fwd = tuple((bv >> a) & 1 for a in range(n))
    return fwd, tuple(reversed(fwd))

phys = {k: block_bits(v) for k, v in blocks.items()}

for hexpath in CANDIDATES:
    ref = [int(l, 16) for l in open(hexpath) if l.strip()]
    assert len(ref) == SIZE
    slices = {}
    for lane in range(8):
        for half in range(2):
            slices[(lane, half)] = tuple((ref[half * HALF + a] >> lane) & 1 for a in range(HALF))
    # match each block against slices (either bit order)
    matches = {}
    for k, (fwd, rev) in phys.items():
        hit = [s for s, vec in slices.items() if vec == fwd or vec == rev]
        matches[k] = hit
    unmatched_blocks = [k for k, h in matches.items() if not h]
    # perfect-matching check on the bipartite hit graph (greedy on unique-choice first)
    used, assign, pool = set(), {}, dict(matches)
    progress = True
    while pool and progress:
        progress = False
        for k in sorted(pool, key=lambda k: len(pool[k])):
            opts = [s for s in pool[k] if s not in used]
            if len(opts) >= 1:
                assign[k] = opts[0]
                used.add(opts[0])
                del pool[k]
                progress = True
                break
        else:
            break
    covered = len(used)
    print("%s :" % hexpath)
    print("  blocks with >=1 slice match: %d/16 ; slices covered by bijection: %d/16 ; unmatched blocks: %d"
          % (16 - len(unmatched_blocks), covered, len(unmatched_blocks)))
    if len(unmatched_blocks) == 0 and covered == 16:
        print("  VERDICT: PERFECT BIJECTION -- image ROM content == %s" % hexpath)
    else:
        # count which slices went unmatched
        missing = [s for s in slices if s not in used]
        print("  VERDICT: MISMATCH -- uncovered slices (lane,half): %s" % missing)
