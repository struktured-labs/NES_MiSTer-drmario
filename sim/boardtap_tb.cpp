// BoardTap co-sim: drive the host write bus exactly as the game CPU does
// (128 board bytes, 4 colours, then GO), decode the UART line, and assert the
// recovered packet byte-for-byte. Also exercises the overrun path.
#include "VBoardTap.h"
#include "verilated.h"
#include <cstdio>
#include <cstdlib>
#include <vector>

static VBoardTap *dut;
static vluint64_t tick_count = 0;

static void tick() {
    dut->clk = 0; dut->eval();
    dut->clk = 1; dut->eval();
    tick_count++;
}

// --- UART receiver (8N1), sampled at the middle of each bit ------------------
struct Rx {
    int divisor;
    std::vector<unsigned char> bytes;
    int state = 0, cnt = 0, bit = 0, sh = 0;
    explicit Rx(int d) : divisor(d) {}
    void sample(int tx) {
        if (state == 0) {                    // idle, wait for start bit
            if (!tx) { state = 1; cnt = divisor / 2; }
        } else if (state == 1) {             // centre of start bit
            if (--cnt <= 0) { state = 2; cnt = divisor; bit = 0; sh = 0; }
        } else if (state == 2) {             // data bits
            if (--cnt <= 0) {
                sh |= (tx & 1) << bit;
                cnt = divisor;
                if (++bit == 8) state = 3;
            }
        } else {                             // stop bit
            if (--cnt <= 0) { bytes.push_back((unsigned char)sh); state = 0; }
        }
    }
};

static Rx *rx;
static void tick_rx() { tick(); rx->sample(dut->tx); }

static void host_write(int off, int val) {
    dut->ce = 1; dut->prg_write = 1; dut->copro_sel = 1;
    dut->off = off; dut->din = val;
    tick_rx();
    dut->ce = 0; dut->prg_write = 0; dut->copro_sel = 0;
    tick_rx();
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    dut = new VBoardTap;
    const int DIVISOR = 21477270 / 2000000;   // must match the RTL defaults
    rx = new Rx(DIVISOR);

    dut->clk = 0; dut->ce = 0; dut->prg_write = 0; dut->copro_sel = 0;
    dut->off = 0; dut->din = 0;
    for (int i = 0; i < 20; i++) tick_rx();

    // --- the exact sequence the game CPU performs -----------------------------
    unsigned char expect[132];
    for (int i = 0; i < 128; i++) { expect[i] = (unsigned char)(i * 7 + 3); host_write(i, expect[i]); }
    const unsigned char col[4] = {1, 2, 0, 2};
    for (int i = 0; i < 4; i++) { expect[128 + i] = col[i]; host_write(0x080 + i, col[i]); }
    host_write(0x084, 1);                     // GO

    for (int i = 0; i < 136 * 10 * DIVISOR + 5000; i++) tick_rx();

    int fail = 0;
    printf("received %zu bytes\n", rx->bytes.size());
    if (rx->bytes.size() < 136) { printf("FAIL: short packet\n"); return 1; }
    const unsigned char *p = rx->bytes.data();
    if (p[0] != 0xA5 || p[1] != 0x5A) { printf("FAIL: magic %02x %02x\n", p[0], p[1]); fail++; }
    if (p[2] != 1) { printf("FAIL: seq %d (want 1)\n", p[2]); fail++; }
    unsigned char cs = 0;
    for (int i = 0; i < 132; i++) {
        if (p[3 + i] != expect[i]) { printf("FAIL: payload[%d] got %02x want %02x\n", i, p[3+i], expect[i]); fail++; break; }
        cs ^= expect[i];
    }
    if (p[135] != cs) { printf("FAIL: checksum %02x want %02x\n", p[135], cs); fail++; }
    if (dut->overrun) { printf("FAIL: spurious overrun\n"); fail++; }
    if (!fail) printf("PASS: 132-byte board recovered byte-for-byte, magic+seq+checksum OK\n");

    // --- NEGATIVE CONTROL: GO mid-send must DROP and RAISE overrun ------------
    size_t before = rx->bytes.size();
    host_write(0x084, 1);                     // start packet 2
    for (int i = 0; i < 200; i++) tick_rx();  // ...still sending...
    host_write(0x084, 1);                     // GO again, too early
    for (int i = 0; i < 136 * 10 * DIVISOR + 5000; i++) tick_rx();
    size_t got = rx->bytes.size() - before;
    if (!dut->overrun) { printf("FAIL: overrun NOT raised on GO-during-send\n"); fail++; }
    else if (got > 140)  { printf("FAIL: emitted %zu bytes, expected ONE packet (torn?)\n", got); fail++; }
    else printf("PASS: GO during send dropped the packet and raised overrun (%zu bytes, one packet)\n", got);

    // dump the raw line bytes so the HOST decoder can be proven against the
    // exact stream the RTL emits -- one wire format, checked end to end.
    if (FILE *f = fopen("sim/boardtap_packet.bin", "wb")) {
        fwrite(rx->bytes.data(), 1, rx->bytes.size(), f); fclose(f);
        printf("wrote sim/boardtap_packet.bin (%zu bytes)\n", rx->bytes.size());
    }
    printf(fail ? "\n*** %d FAILURE(S)\n" : "\nALL CHECKS PASSED\n", fail);
    return fail ? 1 : 0;
}
