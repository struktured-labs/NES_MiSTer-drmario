"""Prove every branch of the paired verdict, not just the one we expect.
The gate bug happened because only one direction was exercised."""
import os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.join(os.path.dirname(HERE), "tools")

STA = """Some preamble
+--------------------------------------------------+
; Setup Summary                                    ;
+----------------------------------+--------+------+
; Clock                            ; Slack  ; TNS  ;
+----------------------------------+--------+------+
; emu|pll|x|counter[0]|divclk      ; %(clk85).3f  ; 0.000 ;
; pll_hdmi|y|counter[0]|divclk     ; 0.381  ; 0.000 ;
; emu|pll|x|counter[2]|divclk      ; %(clk).3f  ; 0.000 ;
+----------------------------------+--------+------+
"""
FIT = "Logic utilization (in ALMs) : %s / 41,910 ( %d %% )\n"

def make(d, name, clk85, clk, alm):
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, name + ".sta"), "w").write(STA % {"clk85": clk85, "clk": clk})
    open(os.path.join(d, name + ".fit"), "w").write(FIT % (alm, 90))
    return (os.path.join(d, name + ".sta"), os.path.join(d, name + ".fit"))

cases = [
    ("both close -> CLEAN GO",            0.090, 0.165, 0),
    ("A misses, B closes -> HONEST NO",  -0.040, 0.165, 1),
    ("A closes, B misses -> ANOMALY",     0.090, -0.020, 2),
    ("BOTH miss -> ABOUT HEAD",          -0.040, -0.020, 4),
]
fails = 0
with tempfile.TemporaryDirectory() as d:
    for name, a_slack, b_slack, want in cases:
        a = make(d, "a", a_slack, 3.007, "37,900")
        b = make(d, "b", b_slack, 3.007, "37,664")
        r = subprocess.run([sys.executable, os.path.join(TOOLS, "paired_verdict.py"),
                            a[0], a[1], b[0], b[1]], capture_output=True, text=True)
        ok = r.returncode == want
        fails += not ok
        print("  %s %-38s rc=%d want=%d" % ("PASS" if ok else "FAIL", name, r.returncode, want))
        if want == 4 and ok:
            assert "ABOUT *HEAD*" in r.stdout, "the loud HEAD flag must appear"
            print("       (loud HEAD flag present, as required)")
        if want == 0 and ok:
            assert "CLEAN GO" in r.stdout and "-0.075" in r.stdout, r.stdout[-400:]
            print("       (delta reported: A-B on the binding clock = -0.075 ns)")
print()
print("VERDICT LOGIC OK: all four branches" if not fails else "*** BROKEN")
sys.exit(1 if fails else 0)
