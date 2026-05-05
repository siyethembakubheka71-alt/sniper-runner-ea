# Backtest Parameter Set - Sniper Runner EA v2

## Recommended Symbols & Timeframes

| Symbol | Timeframe | Spread (typical) | Volatility | Recommendation |
|--------|-----------|------------------|------------|----------------|
| **EURUSD** | M15 | 0.1-0.3 pips | Medium | **Primary** - Best for breakout |
| **GBPUSD** | M15 | 0.2-0.5 pips | High | Good - Wider swings, more breakout |
| **USDJPY** | M15 | 0.1-0.3 pips | Medium | Good - Clean trends |
| **XAUUSD** | M15 | 2-5 pips | Very High | Advanced only - High risk/reward |
| **US30** | M15 | 1-3 pips | Very High | Advanced only - Index behavior |

**Note:** Always use your broker's exact symbol name (some use `.cash`, `#`, etc.)

---

## Conservative Backtest Set (Recommended Start)

### Parameters
```
=== LOT & RISK ===
LotSize           = 0.01
MaxRiskPercent    = 1.0
UseATRSizing      = false    (Start with fixed lots)

=== STOP LOSS & TAKE PROFIT ===
StopLoss_Pips     = 20
TakeProfit_Pips   = 30
Breakeven_Pips    = 15

=== ATR DYNAMIC STOPS ===
UseATRStops       = true
ATR_Period        = 14
ATR_SL_Multiplier = 2.0
ATR_TP_Multiplier = 3.0

=== EMA TREND FILTER ===
EMA_Fast          = 50
EMA_Slow          = 200

=== PARTIAL CLOSE ===
PartialClosePercent = 0.5
PartialClose_Pips   = 25

=== SESSION & SPREAD FILTERS ===
MaxSpread_Pips    = 3
UseLondonFilter   = false
UseNYFilter       = false

=== DAILY DRAWDOWN CUTOFF ===
MaxDailyDrawdownPercent = 3.0

=== EA SETTINGS ===
MagicNumber       = 777
Slippage          = 5
MaxTradesPerBar   = 1
```

**Expected Behavior:**
- Lower frequency trades
- Wider stops for noise filtering
- 1:1.5+ risk/reward ratio
- Max 3% daily drawdown halt

---

## Aggressive Backtest Set (Experienced Only)

### Parameters
```
=== LOT & RISK ===
LotSize           = 0.02
MaxRiskPercent    = 2.0
UseATRSizing      = true     (Risk-based sizing)

=== STOP LOSS & TAKE PROFIT ===
StopLoss_Pips     = 10
TakeProfit_Pips   = 15
Breakeven_Pips    = 5

=== ATR DYNAMIC STOPS ===
UseATRStops       = true
ATR_Period        = 10       (More responsive)
ATR_SL_Multiplier = 1.2
ATR_TP_Multiplier = 1.5

=== EMA TREND FILTER ===
EMA_Fast          = 20       (Faster signals)
EMA_Slow          = 100

=== PARTIAL CLOSE ===
PartialClosePercent = 0.3      (Close less, let winners run)
PartialClose_Pips   = 15

=== SESSION & SPREAD FILTERS ===
MaxSpread_Pips    = 2
UseLondonFilter   = true       (Only high-volatility session)
UseNYFilter       = false

=== DAILY DRAWDOWN CUTOFF ===
MaxDailyDrawdownPercent = 5.0

=== EA SETTINGS ===
MagicNumber       = 777
Slippage          = 3
MaxTradesPerBar   = 1
```

**Expected Behavior:**
- Higher frequency
- Tighter stops (more stop-outs but bigger wins)
- Session-concentrated trading
- 2% risk per trade with ATR sizing

---

## Backtest Periods

### Minimum Recommended
- **1 year** of recent data (last 12 months)
- Include at least one major volatility event

### Ideal
- **3+ years** including:
  - Trending periods (2021, 2022)
  - Ranging periods (2023 parts)
  - High volatility (COVID crash, Ukraine conflict, rate hikes)

### Critical Dates to Include
| Event | Date | Why It Matters |
|-------|------|----------------|
| COVID Crash | Mar 2020 | Extreme volatility test |
| Recovery Rally | Apr-Jun 2020 | Strong trend test |
| 2021 Trend | Most of 2021 | Sustained directional |
| Fed Tightening | 2022 | High volatility, reversals |
| 2023 Range | Mid 2023 | Sideways market test |
| Israel-Gaza | Oct 2023 | News-driven volatility |

---

## Backtest Settings in MT5

### Modeling Quality
```
Every tick (most precise) - REQUIRED for accurate results
OR
OHLC on M1 (acceptable for faster testing, less precise)
```

### Spread
```
Current (use real-time spread)
OR
Set fixed spread: 0.00010 for EURUSD (1 pip)
```

### Commission
```
Add your broker's commission per lot
Example: $7 per round turn lot → enter 7.0
```

### Slippage
```
Set to same as EA input: 5 points (0.5 pips on 5-digit broker)
```

### Testing Period
```
Start: 2022-01-01
End:   Current date
```

### Execution Mode
```
Execution: By market prices (not instant - more realistic)
```

---

## What to Look For in Results

### Minimum Acceptable Metrics
| Metric | Conservative | Aggressive |
|--------|--------------|------------|
| **Total Net Profit** | >$100 (on $10k, 0.01 lots) | >$200 |
| **Profit Factor** | >1.5 | >1.3 |
| **Expected Payoff** | >$5 per trade | >$3 per trade |
| **Max Drawdown %** | <15% | <25% |
| **Recovery Factor** | >2.0 | >1.5 |
| **Sharpe Ratio** | >0.5 | >0.3 |
| **Win Rate** | 40-60% | 35-55% |
| **Consecutive Losses** | <10 | <15 |

### Red Flags
- [ ] Profit Factor < 1.0 (losing strategy)
- [ ] Max Drawdown > 50% (too risky)
- [ ] Recovery Factor < 1.0 (can't recover)
- [ ] Win Rate < 30% (needs very high R:R)
- [ ] Consecutive Losses > 20 (psychologically hard to trade)

---

## Walk-Forward Analysis

### What It Is
Test optimization on past data, then verify on unseen future data.

### Steps
1. **In-Sample Period:** Optimize on Jan 2022 - Dec 2023
2. **Out-of-Sample Test:** Run with those settings on Jan 2024 - Present
3. **Compare:** In-sample results should roughly match out-of-sample

### If Results Diverge
- Strategy is over-optimized (curve-fitted)
- Reduce parameters or use more conservative settings
- Extend in-sample period

---

## Forward Testing (Demo Live)

After successful backtest:

### Phase 1: Demo (2-4 weeks)
- Run on demo account with same parameters
- Compare actual fills vs backtest
- Note any broker-specific issues (freeze level, requotes)

### Phase 2: Micro Live (1-2 weeks)
- $100-500 account
- 0.01 lots maximum
- Verify emotional/psychological comfort with drawdown

### Phase 3: Scale Up
- Increase lot size gradually
- Maintain same risk % per trade
- Never risk more than you can afford to lose

---

## Monthly Review Checklist

After first month live:
- [ ] Compare actual vs backtested trades
- [ ] Check if spread assumptions were accurate
- [ ] Verify slippage within acceptable range
- [ ] Assess if drawdown periods match expectations
- [ ] Adjust parameters if market regime changed

---

## Broker-Specific Considerations

| Broker Type | Consideration |
|-------------|---------------|
| ECN/STP | Lower spreads, commission-based - use commission input |
| Market Maker | Wider spreads, no commission - watch for spread widening |
| Raw Spread | Very low spread + commission - most accurate for backtest |
| Cent Account | Good for micro testing, but spreads may differ |

**Always backtest on the EXACT account type you will trade live.**

---

## Recommended Backtest Schedule

- **Weekly:** Quick run on last 6 months to check recent performance
- **Monthly:** Full 3-year backtest to detect market regime changes
- **Quarterly:** Re-optimize if performance degraded significantly
- **Yearly:** Full strategy review, consider retirement if no longer profitable

---

## Final Warning

> **Past performance does not guarantee future results.**
> 
> A strategy that backtests well can fail live due to:
> - Changing market conditions
> - Broker execution differences
> - Over-optimization
> - Slippage and spread variations
> - News events not in historical data

**Never risk money you cannot afford to lose. Start small, scale gradually, and always have a stop-loss.**
