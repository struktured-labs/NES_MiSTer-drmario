#!/usr/bin/env python3
"""boardtap_read.py — host-side decoder for the BoardTap UART conduit.

Reads the 136-byte packets the core emits once per pill and prints the board.

  wire format: A5 5A | seq | 128 board bytes | cA cB nA nB | xor-checksum

On the MiSTer the line is the tty the daemon configures for this core's
CONF_STR UART entry (observed: "ttyS1: 31250" in the daemon's own startup log):

  ./boardtap_read.py /dev/ttyS1 --baud 2000000
  ./boardtap_read.py sim/boardtap_packet.bin        # replay a captured stream

Tile decoding matches the supergod bridge: hi-nibble $D = virus, $8/$B single,
$4/$5/$6/$7 = the four half-links; low nibble mod 3 selects the colour.
"""
import argparse
import sys

MAGIC = b"\xA5\x5A"
PACKET = 136
PAYLOAD = 132
HALF = {0x4: "v", 0x5: "^", 0x6: ">", 0x7: "<", 0x8: "o", 0xB: "o"}
COLOR = "YRB"                       # low nibble % 3 -> colour glyph


def decode(pkt):
    """pkt = the 136 bytes. Returns (seq, board[128], colours[4]) or raises."""
    if pkt[0:2] != MAGIC:
        raise ValueError("bad magic %02x %02x" % (pkt[0], pkt[1]))
    body = pkt[3:3 + PAYLOAD]
    csum = 0
    for b in body:
        csum ^= b
    if csum != pkt[135]:
        raise ValueError("checksum %02x, computed %02x" % (pkt[135], csum))
    return pkt[2], list(body[:128]), list(body[128:132])


def render(board):
    rows = []
    for r in range(16):
        out = []
        for c in range(8):
            v = board[r * 8 + c]
            if v in (0x00, 0xFF):
                out.append(".")
                continue
            hi, lo = v >> 4, v & 0x0F
            col = COLOR[lo % 3]
            out.append(col.lower() if hi == 0xD else col)
        rows.append("".join(out))
    return rows


def packets(stream):
    """Yield 136-byte packets, resynchronising on the magic."""
    buf = bytearray()
    while True:
        chunk = stream.read(64)
        if not chunk:
            return
        buf += chunk
        while True:
            i = buf.find(MAGIC)
            if i < 0:
                del buf[:max(0, len(buf) - 1)]
                break
            if len(buf) - i < PACKET:
                del buf[:i]
                break
            yield bytes(buf[i:i + PACKET])
            del buf[:i + PACKET]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", help="tty device or a captured byte stream")
    ap.add_argument("--baud", type=int, default=2000000)
    ap.add_argument("--count", type=int, default=0, help="stop after N packets")
    a = ap.parse_args()

    if a.source.startswith("/dev/"):
        import serial                       # pyserial, only needed for a tty
        fh = serial.Serial(a.source, a.baud, timeout=1)
    else:
        fh = open(a.source, "rb")

    n = 0
    for pkt in packets(fh):
        try:
            seq, board, col = decode(pkt)
        except ValueError as e:
            print("packet rejected: %s" % e, file=sys.stderr)
            continue
        n += 1
        virus = sum(1 for v in board if (v >> 4) == 0xD)
        occ = sum(1 for v in board if v not in (0x00, 0xFF))
        print("seq=%-4d cur=(%d,%d) next=(%d,%d) viruses=%d occupied=%d"
              % (seq, col[0], col[1], col[2], col[3], virus, occ))
        for row in render(board):
            print("   " + row)
        if a.count and n >= a.count:
            break
    if n == 0:
        print("no valid packets decoded", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
