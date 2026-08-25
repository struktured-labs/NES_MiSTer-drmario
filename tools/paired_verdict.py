#!/usr/bin/env python3
"""paired_verdict.py — turn the two fits into the answer, in the required form.

Emits the three statements the pair exists to support:
  (1) the BINDING CLOCK NAMED for each fit (never counter[N]);
  (2) confirmation A and B ran under identical settings (asserted, not implied);
  (3) the A-vs-B DELTA stated as the answer, with the Aug-21 table explicitly
      labelled a NON-COMPARABLE reference rather than a baseline.

Outcome rules are fixed in advance so the reading is not chosen after seeing
the numbers:
  A closes, B closes  -> clean GO for the owner's decision
  A misses, B closes  -> honest NO on the feature
  A closes, B misses  -> ANOMALY (the feature cannot plausibly help timing)
  BOTH miss           -> the conclusion is about HEAD, NOT BoardTap
"""
import subprocess
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fit_report import parse, name_clock          # noqa: E402

# ⚠ These are TWO DIFFERENT BUILDS, 16 days apart, and were previously quoted
# as one baseline. Neither is a control for a current fit, and they are not
# controls for each other. B (the paired control) is the only control here.
AUG21 = ("Aug-21 respin-144 build (HEAD 08f2343): binding clk85 +0.165 ns, "
         "37,664/41,910 = 90% ALM. | SEPARATELY, SEED_SWEEP_TABLE.csv is the "
         "Aug-5 STOMPER campaign, a different revision whose config is lost: "
         "seed 13 closed at +0.051 ns. Different builds — do not read as one "
         "baseline.")


def binding(rows):
    return min(rows, key=lambda r: r[1])


def report(a_sta, a_fit, b_sta, b_fit, audit_cmd=None):
    ra, ua = parse(a_sta, a_fit)
    rb, ub = parse(b_sta, b_fit)
    if not ra or not rb:
        print("CANNOT ADJUDICATE: %s fit produced no timing data."
              % ("A (BoardTap)" if not ra else "B (control)"))
        return 3
    ba, bb = binding(ra), binding(rb)

    print("=" * 74)
    print("PAIRED CLOSURE VERDICT — BoardTap vs HEAD control, same seed/settings/box")
    print("=" * 74)

    print("\n(1) BINDING CLOCK, NAMED, PER FIT")
    print("    A  HEAD + BoardTap : %-32s %+0.3f ns" % (name_clock(ba[0]), ba[1]))
    print("    B  HEAD control    : %-32s %+0.3f ns" % (name_clock(bb[0]), bb[1]))
    print("    A closes: %-3s     B closes: %s"
          % ("YES" if ba[1] >= 0 else "NO", "YES" if bb[1] >= 0 else "NO"))

    print("\n(2) SETTINGS HELD CONSTANT (the entire point of the pair)")
    if audit_cmd:
        rc = subprocess.run(audit_cmd, shell=True, capture_output=True, text=True)
        tail = [l for l in rc.stdout.splitlines() if "AUDIT" in l or "SEED" in l]
        for l in tail:
            print("    " + l.strip())
        if rc.returncode != 0:
            print("    *** AUDIT FAILED — DO NOT READ THE DELTA AS CONTROLLED ***")
    else:
        print("    (audit not run)")

    print("\n(3) THE DELTA IS THE ANSWER")
    da = {name_clock(r[0]): r[1] for r in ra}
    db = {name_clock(r[0]): r[1] for r in rb}
    print("    %-34s %9s %9s %9s" % ("clock", "A", "B", "A-B"))
    for k in sorted(set(da) & set(db), key=lambda k: da[k]):
        print("    %-34s %+9.3f %+9.3f %+9.3f" % (k, da[k], db[k], da[k] - db[k]))
    cost = ba[1] - db.get(name_clock(ba[0]), bb[1])
    print("\n    Cost of BoardTap on A's binding clock (%s): %+0.3f ns"
          % (name_clock(ba[0]), cost))
    for label, u in (("A", ua), ("B", ub)):
        if u.get("Logic utilization"):
            print("    %s utilisation: %s" % (label, u["Logic utilization"]))

    print("\n    REFERENCE ONLY, NOT A BASELINE: %s" % AUG21)
    print("    That build ran under project settings that exist only in one")
    print("    working tree (uncommitted NES.qsf), so it is NOT comparable to")
    print("    either fit here. B is the control; the table is context.")

    print("\n" + "=" * 74)
    if ba[1] >= 0 and bb[1] >= 0:
        print("VERDICT: CLEAN GO for the owner's decision.")
        print("  Both close. BoardTap costs %+0.3f ns on %s." % (cost, name_clock(ba[0])))
        rc = 0
    elif ba[1] < 0 <= bb[1]:
        print("VERDICT: HONEST NO on the feature.")
        print("  The control closes and BoardTap does not: the logic is what broke it.")
        rc = 1
    elif ba[1] >= 0 > bb[1]:
        print("VERDICT: ANOMALY — A closes but the CONTROL does not.")
        print("  Adding logic cannot plausibly improve timing, so read this as fitter")
        print("  noise at this utilisation, not as a result. Re-run before concluding.")
        rc = 2
    else:
        print("!" * 74)
        print("VERDICT: BOTH FITS MISS — THE CONCLUSION IS ABOUT *HEAD*, NOT BoardTap.")
        print("  The control alone fails to close, so committed HEAD does not close")
        print("  at this seed. That is a statement about the canon core's")
        print("  reproducibility, NOT a verdict on the feature, and it is the more")
        print("  important finding of the two. Do not read it as a BoardTap failure.")
        print("!" * 74)
        rc = 4
    print("=" * 74)
    return rc


if __name__ == "__main__":
    sys.exit(report(*sys.argv[1:6]) if len(sys.argv) >= 5 else 64)
