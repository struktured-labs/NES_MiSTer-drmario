#!/usr/bin/env python3
"""PROVE which firmware bytes are inside the BUILT MiSTer image.

WHY THIS EXISTS
---------------
`quartus_cdb --update_mif` is a silent NO-OP for a $readmemh-initialised ROM, and
Quartus smart recompilation can degenerate a full `--flow compile` into the same
no-op (memory: quartus-update-mif-readmemh). Both failure modes exit 0 and emit
the OLD bitstream. Verifying the RECIPE, the hex on disk, or the command's exit
status therefore proves nothing about the artifact. This script reads the
firmware CONTENTS back out of the compiled design database and compares them,
byte for byte, against candidate firmware hex files.

WHAT IT READS
-------------
The post-fit EDA simulation netlist (`quartus_eda --simulation --format=verilog`)
serialises every M20K's `mem_initN` parameters from the SAME compiled database
that `quartus_asm` turned into NES.sof / NES.rbf. The copro firmware lives in
    emu|nes|multi_mapper|copro2|rom_rtl_0|auto_generated|ram_block*
as 16 one-bit-wide M20K slices (8 bit lanes x 2 address halves of a 16384x8 ROM).
This reassembles them into the 16 KB byte image.

KILLED-MUTANT CONTROL (this is the gate, not the match)
-------------------------------------------------------
A match against the intended firmware is not by itself evidence -- a broken
extractor that returned the intended bytes would also "match". So the script
REQUIRES that the extracted image mismatch every control firmware it is given,
and reports the diff positions. th150 vs th400 differ in exactly 2 bytes
(the 16-bit theta dose constant), which makes the tightest possible control:
an extractor that cannot tell th150 from th400 cannot tell any two firmwares
apart, and a build that flashed the wrong dose would show exactly those bytes.

Usage:
  tools_verify_fw_in_image.py <NES.vo> <expected.hex> [control.hex ...]
Exit: 0 = image == expected AND differs from every control; 1 = otherwise.
"""
import re
import sys

SIZE = 16384
ROM_INST = "copro2|rom_rtl_0"

DEFPARAM = re.compile(
    r'defparam\s+\\(\S+)\s+\.(\w+)\s*=\s*(?:"([^"]*)"|([^;]+));')


def load_hex(path):
    vals = [int(t, 16) for t in open(path).read().split()]
    if len(vals) != SIZE:
        sys.exit("%s: expected %d hex bytes, got %d" % (path, SIZE, len(vals)))
    return vals


def extract(vo_path):
    blocks = {}
    with open(vo_path, "r", errors="replace") as fh:
        for line in fh:
            if ROM_INST not in line or "defparam" not in line:
                continue
            m = DEFPARAM.search(line)
            if not m:
                continue
            inst, param = m.group(1), m.group(2)
            val = m.group(3) if m.group(3) is not None else m.group(4).strip()
            blocks.setdefault(inst, {})[param] = val
    blocks = {k: v for k, v in blocks.items() if "mem_init0" in v}
    if not blocks:
        sys.exit("no %s ram blocks with mem_init found in %s" % (ROM_INST, vo_path))

    # Every slice is 1 bit x 8192 and reports port_a_first_address 0: a 16384x8 ROM
    # is built from TWO groups of 8 M20Ks, and which group holds the upper 8K is a
    # mux in the fabric, not a defparam. So reconstruct both 8K halves and let the
    # comparison establish the order -- and REQUIRE that exactly one order matches,
    # so a swap can never be waved through.
    groups = {}
    for inst, v in sorted(blocks.items()):
        fa = int(v["port_a_first_address"])
        la = int(v["port_a_last_address"])
        fb = int(v["port_a_first_bit_number"])
        dw = int(v["port_a_data_width"])
        assert dw == 1, "unexpected slice width %d on %s" % (dw, inst)
        idx = int(re.search(r"ram_block\d+a(\d+)$", inst).group(1))
        inits = sorted((p for p in v if re.fullmatch(r"mem_init\d+", p)),
                       key=lambda p: int(p[8:]))
        blob = "".join(v[p] for p in reversed(inits))
        bv = int(blob, 16) if blob.strip() else 0
        g = 0 if idx < 8 else 1
        bits = groups.setdefault(g, {})
        for a in range(la - fa + 1):
            bits[(fa + a, fb)] = (bv >> a) & 1
    print("ROM slices found : %d in %d groups" % (len(blocks), len(groups)))
    if sorted(groups) != [0, 1]:
        sys.exit("FAIL: expected 2 slice groups, got %s" % sorted(groups))

    halves = []
    for g in (0, 1):
        bits = groups[g]
        half = []
        for a in range(SIZE // 2):
            byte, ok = 0, True
            for b in range(8):
                bit = bits.get((a, b))
                if bit is None:
                    ok = False
                    break
                byte |= bit << b
            if not ok:
                sys.exit("FAIL: group %d missing bits at address %d" % (g, a))
            half.append(byte)
        halves.append(half)
    print("bytes recovered  : %d/%d (2 x 8192-byte halves)" % (SIZE, SIZE))
    return [halves[0] + halves[1], halves[1] + halves[0]]


def diff(img, ref):
    return [(i, ref[i], img[i]) for i in range(SIZE) if img[i] != ref[i]]


def main():
    vo, expected = sys.argv[1], sys.argv[2]
    controls = sys.argv[3:]
    orders = extract(vo)

    rc = 0
    exp = load_hex(expected)
    ds = [diff(o, exp) for o in orders]
    matched = [i for i, d in enumerate(ds) if not d]
    order_name = ["low-half=group0", "low-half=group1"]
    if len(matched) == 1:
        img = orders[matched[0]]
        print("EXPECTED %s : MATCH 16384/16384 bytes (%s; the other order differs in "
              "%d bytes)" % (expected, order_name[matched[0]],
                             len(ds[1 - matched[0]])))
    elif len(matched) == 2:
        print("EXPECTED %s : AMBIGUOUS -- both half-orders match, halves are identical"
              % expected)
        return 1
    else:
        img = orders[0]
        best = min(ds, key=len)
        print("EXPECTED %s : MISMATCH (best order differs in %d/%d bytes)"
              % (expected, len(best), SIZE))
        for i, r, g in best[:10]:
            print("    addr %5d  hex %02x  image %02x" % (i, r, g))
        rc = 1

    for c in controls:
        ref = load_hex(c)
        dcs = [diff(o, ref) for o in orders]
        if all(dcs):
            n = min(len(d) for d in dcs)
            print("CONTROL  %s : DIFFERS in every half-order (min %d byte(s))" % (c, n))
            for i, r, g in min(dcs, key=len)[:10]:
                print("    addr %5d  control %02x  image %02x" % (i, r, g))
        else:
            print("CONTROL  %s : IDENTICAL to the image -- CONTROL FAILED" % c)
            rc = 1

    print("IMAGE-PROOF %s" % ("PASS" if rc == 0 else "FAIL"))
    return rc


if __name__ == "__main__":
    sys.exit(main())
