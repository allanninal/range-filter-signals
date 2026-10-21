# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Compare RangeFilterSignals in MT5 (DumpIndicator CSVs) with tests/reference.py, bar by bar.

The dumps go in <out dir>/dump/<tag>_<SYMBOL>_<TF>.csv.
    python3 tests/check_parity.py <out dir>   (needs numpy and pandas)
    python3 tests/check_parity.py <out dir> --mt4     (the MT4 edition, dumps from the MT4 tester)

Buffers: b0 buy arrow, b1 sell arrow, b2 filter, b4/b5 bands, b6 side, b7 range, b8 setup state. The indicator scans
InpHistory closed bars. Pass: filter, bands and range within 1e-9 relative; side, setup and arrows identical."""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from reference import run  # noqa: E402

CONFIGS = {"rf_default": (100, 3.0, 3000), "rf_p20_m2": (20, 2.0, 3000)}


def num(col):
    return pd.to_numeric(col, errors="coerce").to_numpy(float)


def close(a, b):
    return np.isclose(a, b, rtol=1e-9, atol=0, equal_nan=True)


def check(csv, period, mult, hist, mt4=False):
    d = pd.read_csv(csv)
    n = len(d)
    start = max(0, n - 1 - hist)
    if mt4:   # MT4 tester: the indicator starts InpHistory bars before the bar it was attached on, then keeps feeding
        start = int(np.flatnonzero(~np.isnan(num(d["b2"])))[0]) - 1    # the filter starts on the second bar fed
    c = d["close"].to_numpy(float)[start:n - 1]
    rows = run(list(c), period, mult)
    m = len(rows)
    nan = lambda v: np.nan if v is None else v  # noqa: E731
    f = np.array([nan(r["filt"]) for r in rows])
    rg = np.array([nan(r["range"]) if r["filt"] is not None else np.nan for r in rows])
    sl = slice(start, start + m)
    ok_f = close(num(d["b2"])[sl], f)
    ok_r = close(num(d["b7"])[sl], rg)
    ok_hi = close(num(d["b4"])[sl], f + rg)
    side = np.array([r["side"] if r["filt"] is not None else np.nan for r in rows])
    cond = np.array([r["cond"] if r["filt"] is not None else np.nan for r in rows])
    ok_s = close(num(d["b6"])[sl], side)
    ok_c = close(num(d["b8"])[sl], cond)
    buys = list(np.flatnonzero(~np.isnan(num(d["b0"])[sl])))
    sells = list(np.flatnonzero(~np.isnan(num(d["b1"])[sl])))
    rb = [k for k, r in enumerate(rows) if r["ev"] > 0]
    rs = [k for k, r in enumerate(rows) if r["ev"] < 0]
    ok = all(x.all() for x in (ok_f, ok_r, ok_hi, ok_s, ok_c)) and buys == rb and sells == rs
    msg = (f"{csv.stem:30} bars {m:>5}  filter {'OK' if ok_f.all() else (~ok_f).sum()}  range {'OK' if ok_r.all() else (~ok_r).sum()}"
           f"  bands {'OK' if ok_hi.all() else (~ok_hi).sum()}  side {'OK' if ok_s.all() else (~ok_s).sum()}"
           f"  setup {'OK' if ok_c.all() else (~ok_c).sum()}  buys {len(rb):>3} {'OK' if buys == rb else 'DIFFER'}"
           f"  sells {len(rs):>3} {'OK' if sells == rs else 'DIFFER'}")
    return ok, msg


if __name__ == "__main__":
    mt4 = "--mt4" in sys.argv          
    root = Path([a for a in sys.argv[1:] if a != "--mt4"][0])
    allok, k = True, 0
    for tag, (p, m, h) in CONFIGS.items():
        for f in sorted(root.glob(f"dump/{tag}_*.csv")):
            ok, msg = check(f, p, m, h, mt4)
            allok &= ok
            k += 1
            print(("PASS " if ok else "FAIL ") + msg)
    print(f"\n{'ALL PASS' if allok and k else 'FAILURES'} ({k} files)")
