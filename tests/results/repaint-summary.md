# Repaint check results (run on the code in this repository)

MT5, Strategy Tester every-tick run, XAUUSD H1, January to October 2026, default inputs (RepaintProbe EA):

| field | value |
|---|---|
| ticks processed | 91,052,717 |
| closed bars checked | 4,406 |
| signals seen when the bar closed | 131 |
| values changed after the close | 0 |
| signals ever shown on the live bar | 0 |

MT4, Strategy Tester (Dump4.mqh + RangeFilterDump.mq4, live mode), 25 runs = 4 symbols (EURUSD, XAUUSD, GBPJPY, BTCUSD)
x M15/H1/H4 x 2 input sets (+1 every-tick EURUSD H1 run, 8,417,316 tick events), totals over all 25 runs:

| field | value |
|---|---|
| closed bars checked | 505,320 |
| signals seen when the bar closed | 21,079 |
| mismatches with the final values | 0 |
| signals on the live bar | 0 |
| bars not found again | 0 |

The raw price dumps behind the parity runs are not published (broker price data).
