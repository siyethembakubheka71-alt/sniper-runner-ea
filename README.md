# Sniper Runner EA v2

MT5 Breakout Expert Advisor with ATR-based risk management, EMA trend filtering, and production-ready safeguards.

## Files

| File | Description |
|------|-------------|
| **SniperRunner_EA_v2.mq5** | The EA source code |
| **VPS_AUTO_START_GUIDE.md** | Complete VPS setup + MT5 auto-start guide |
| **BACKTEST_PARAMETERS.md** | Recommended backtest settings + performance targets |

## Quick Start

1. **Download**  to your MT5  folder
2. **Compile** in MetaEditor (F7)
3. **Attach** to M15 chart on EURUSD
4. **Set** inputs according to 
5. **Enable** AutoTrading

## Key Features

- ATR dynamic stop loss & take profit
- ATR-based lot sizing (% risk per trade)
- EMA trend filter (50/200)
- Partial close at profit targets
- Breakeven trigger
- Daily drawdown cutoff (halts trading)
- Max spread filter
- London/NY session filters
- One trade per bar safety
- Symbol + MagicNumber filtering

## Risk Warning

This is a breakout strategy. It will lose money in ranging markets. Always:
- Backtest 2+ years before live
- Start on demo for 4-6 weeks
- Use 0.01 lots initially
- Never risk more than you can afford to lose

## Setup VPS for 24/7 Trading

See [VPS_AUTO_START_GUIDE.md](VPS_AUTO_START_GUIDE.md) for:
- Recommended providers (Contabo, Vultr, AWS)
- RDP connection steps
- Silent MT5 installation
- Windows Task Scheduler auto-start
- Auto-login configuration

## License

Use at your own risk. No warranty provided.
