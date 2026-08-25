#!/usr/bin/env python3
"""Parse one Quartus fit's timing + utilisation, naming the binding clock.

The Setup Summary lists PLL counters, not names, which is how you end up
adding logic to a clock you did not realise was the tight one. NES.sv maps
them: outclk_0 = clk85 (85.9 MHz copro clock), outclk_1 = CLK_VIDEO,
outclk_2 = clk (~21.5 MHz NES clock). So resolve them here, every time.
"""
import re
import sys

CLOCK_NAMES = {
    "counter[0]": "clk85  (85.9 MHz copro clock)",
    "counter[1]": "CLK_VIDEO",
    "counter[2]": "clk    (~21.5 MHz NES clock)",
}


def name_clock(raw):
    if "pll_hdmi" in raw:
        return "pll_hdmi"
    for k, v in CLOCK_NAMES.items():
        if k in raw and "pll_hdmi" not in raw:
            return v
    return raw.split("|")[-1] if "|" in raw else raw


def parse(sta_path, fit_path):
    rows, util = [], {}
    try:
        lines = open(sta_path, errors="replace").read().splitlines()
    except OSError:
        return None, None
    # Scan forward from the marker. A regex bounded by "+---" terminates on the
    # table's OWN separator, which is one line below the heading — collect rows
    # by shape instead, and stop at the first separator AFTER real data.
    i = next((n for n, l in enumerate(lines) if l.strip().startswith("; Setup Summary")), None)
    if i is not None:
        for line in lines[i + 1:]:
            if line.startswith("+") and rows:
                break
            f = [x.strip() for x in line.split(";")]
            if len(f) >= 4 and re.match(r"^-?\d+\.\d+$", f[2] or ""):
                rows.append((f[1], float(f[2]), f[3]))
    try:
        for line in open(fit_path, errors="replace"):
            for key in ("Logic utilization", "Total registers",
                        "Total RAM Blocks", "Total DSP Blocks"):
                if line.strip().startswith(key):
                    util[key] = line.split(":", 1)[1].strip()
    except OSError:
        pass
    return rows, util


def main():
    label, sta, fit = sys.argv[1], sys.argv[2], sys.argv[3]
    rows, util = parse(sta, fit)
    print("=" * 72)
    print(label)
    print("=" * 72)
    if not rows:
        print("  NO TIMING DATA — the fit did not produce an STA report.")
        return 2
    rows.sort(key=lambda r: r[1])
    worst = rows[0]
    for raw, slack, tns in rows:
        flag = "  <-- BINDING" if raw == worst[0] else ""
        print("  %-34s slack %+7.3f ns   TNS %s%s"
              % (name_clock(raw), slack, tns, flag))
    print()
    print("  CLOSES: %s   (worst slack %+0.3f ns on %s)"
          % ("YES" if worst[1] >= 0 else "NO", worst[1], name_clock(worst[0])))
    for k, v in util.items():
        print("  %-20s %s" % (k + ":", v))
    return 0 if worst[1] >= 0 else 1


if __name__ == "__main__":
    sys.exit(main())
