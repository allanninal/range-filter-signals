# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
# distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/
# Range filter: method popularised by TradingView open-source scripts, notably "Range Filter [DW]" and its variants.
"""Python twin of mql5/Include/RangeFilter/RF.mqh, operation for operation (parity tests and the frequency count).

    from reference import run
    rows = run(close, period=100, mult=3.0)   # per bar: filt, range, upward, downward, cond, ev
"""


def run(src, period=100, mult=3.0):
    rows = []
    prev = 0.0
    avrng = smrng = rng = filt = prev_filt = None
    up = dn = cond = 0
    a1 = 2.0 / (period + 1)
    wper = 2 * period - 1
    a2 = 2.0 / (wper + 1)
    for k, x in enumerate(src):
        ev = 0
        if k >= 1:
            d = abs(x - prev)
            avrng = d if avrng is None else avrng + a1 * (d - avrng)
            smrng = avrng if smrng is None else smrng + a2 * (avrng - smrng)
            rng = smrng * mult
            prev_filt = filt
            if filt is None:
                filt = x
            else:
                f, r = filt, rng
                if x > f:
                    filt = f if x - r < f else x - r
                else:
                    filt = f if x + r > f else x + r
            if prev_filt is not None:
                if filt > prev_filt:
                    up, dn = up + 1, 0
                elif filt < prev_filt:
                    dn, up = dn + 1, 0
            moved = x != prev
            buy = x > filt and moved and up > 0
            sell = x < filt and moved and dn > 0
            p = cond
            if buy:
                cond = 1
            elif sell:
                cond = -1
            if buy and p == -1:
                ev = 1
            elif sell and p == 1:
                ev = -1
        prev = x
        rows.append(dict(filt=filt, range=rng, up=up, dn=dn, cond=cond, ev=ev,
                         side=1 if up > 0 else (-1 if dn > 0 else 0)))
    return rows
