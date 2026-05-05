//+------------------------------------------------------------------+
//| Sniper Runner EA v2 (MT5) - Production Ready                     |
//| Breakout strategy with EMA trend filter, ATR-based risk,          |
//| partial close, breakeven, daily drawdown cutoff, spread filter    |
//+------------------------------------------------------------------+
#property strict
#property version   "2.0"
#property description "Sniper Runner v2 - Breakout EA with ATR risk"

#include <Trade/Trade.mqh>
CTrade trade;

// === INPUTS ===
input group "=== LOT & RISK ==="
input double LotSize           = 0.01;
input double MaxRiskPercent    = 2.0;     // % of equity per trade (if ATR sizing enabled)
input bool   UseATRSizing      = false;   // If true, lot size = risk% / (SL in money)

input group "=== STOP LOSS & TAKE PROFIT ==="
input int    StopLoss_Pips     = 15;      // Fallback SL if ATR disabled
input int    TakeProfit_Pips   = 20;      // Fallback TP if ATR disabled
input int    Breakeven_Pips    = 10;      // Move SL to entry when profit reaches this

input group "=== ATR DYNAMIC STOPS ==="
input bool   UseATRStops       = true;    // Use ATR for SL/TP instead of fixed pips
input int    ATR_Period        = 14;
input double ATR_SL_Multiplier = 1.5;     // SL = ATR * multiplier
input double ATR_TP_Multiplier = 2.0;     // TP = ATR * multiplier

input group "=== EMA TREND FILTER ==="
input int    EMA_Fast          = 50;
input int    EMA_Slow          = 200;

input group "=== PARTIAL CLOSE ==="
input double PartialClosePercent = 0.5;   // Close this % at TP level
input int    PartialClose_Pips   = 20;    // Trigger partial close at this profit

input group "=== SESSION & SPREAD FILTERS ==="
input int    MaxSpread_Pips    = 5;       // Reject entries if spread exceeds this
input bool   UseLondonFilter   = false;   // Only trade during London session (08:00-17:00 UTC)
input bool   UseNYFilter       = false;   // Only trade during NY session (13:00-22:00 UTC)

input group "=== DAILY DRAWDOWN CUTOFF ==="
input double MaxDailyDrawdownPercent = 5.0; // Stop trading for the day if equity drops this % from start

input group "=== EA SETTINGS ==="
input int    MagicNumber       = 777;
input int    Slippage          = 5;
input int    MaxTradesPerBar   = 1;       // Max trades per bar (safety)

// === GLOBALS ===
int      emaFastHandle = INVALID_HANDLE;
int      emaSlowHandle = INVALID_HANDLE;
int      atrHandle     = INVALID_HANDLE;
datetime lastBarTime   = 0;
double   dayStartEquity = 0.0;
datetime currentDay    = 0;
int      tradesThisBar = 0;

// partial close tracker
ulong partialDoneTickets[];
int   partialDoneCount = 0;

//+------------------------------------------------------------------+
//| Utility: pip size                                                 |
//+------------------------------------------------------------------+
double PipSize()
{
   if(_Digits == 3 || _Digits == 5) return _Point * 10.0;
   return _Point;
}

//+------------------------------------------------------------------+
//| Utility: normalize volume                                           |
//+------------------------------------------------------------------+
double NormalizeVolume(double vol)
{
   double vMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(vStep <= 0.0) vStep = 0.01;

   vol = MathMax(vMin, MathMin(vMax, vol));
   vol = MathFloor(vol / vStep) * vStep;
   vol = NormalizeDouble(vol, 2);

   if(vol < vMin) vol = vMin;
   return vol;
}

//+------------------------------------------------------------------+
//| Utility: count positions by symbol+magic                          |
//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long   mg  = PositionGetInteger(POSITION_MAGIC);

      if(sym == _Symbol && mg == MagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Partial close tracker                                               |
//+------------------------------------------------------------------+
bool IsPartialDone(ulong ticket)
{
   for(int i = 0; i < partialDoneCount; i++)
      if(partialDoneTickets[i] == ticket) return true;
   return false;
}

void MarkPartialDone(ulong ticket)
{
   if(IsPartialDone(ticket)) return;
   int newSize = partialDoneCount + 1;
   ArrayResize(partialDoneTickets, newSize);
   partialDoneTickets[partialDoneCount] = ticket;
   partialDoneCount = newSize;
}

void CleanupPartialTracker()
{
   for(int i = partialDoneCount - 1; i >= 0; i--)
   {
      ulong t = partialDoneTickets[i];
      if(!PositionSelectByTicket(t))
      {
         partialDoneTickets[i] = partialDoneTickets[partialDoneCount - 1];
         partialDoneCount--;
         ArrayResize(partialDoneTickets, partialDoneCount);
      }
   }
}

//+------------------------------------------------------------------+
//| Spread check                                                        |
//+------------------------------------------------------------------+
bool IsSpreadOK()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spreadPips = (ask - bid) / PipSize();
   return (spreadPips <= MaxSpread_Pips);
}

//+------------------------------------------------------------------+
//| Session filter                                                      |
//+------------------------------------------------------------------+
bool IsSessionOK()
{
   if(!UseLondonFilter && !UseNYFilter) return true;

   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int hour = dt.hour;

   bool london = (hour >= 8 && hour < 17);
   bool ny     = (hour >= 13 && hour < 22);

   if(UseLondonFilter && !london) return false;
   if(UseNYFilter && !ny) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Daily drawdown check                                                |
//+------------------------------------------------------------------+
bool IsDrawdownOK()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   // Reset at midnight
   if(dt.day != currentDay)
   {
      currentDay = dt.day;
      dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   }

   if(dayStartEquity <= 0.0) return true;

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct = (dayStartEquity - currentEquity) / dayStartEquity * 100.0;

   return (ddPct < MaxDailyDrawdownPercent);
}

//+------------------------------------------------------------------+
//| ATR-based lot sizing                                                |
//+------------------------------------------------------------------+
double GetATRBasedLot(double slPips)
{
   if(!UseATRSizing || slPips <= 0) return NormalizeVolume(LotSize);

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double pointValue = tickValue / tickSize;

   if(tickSize == 0 || tickValue == 0) return NormalizeVolume(LotSize);

   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * MaxRiskPercent / 100.0;
   double slMoney = slPips * PipSize() * pointValue;

   if(slMoney <= 0) return NormalizeVolume(LotSize);

   double lots = riskMoney / slMoney;
   return NormalizeVolume(lots);
}

//+------------------------------------------------------------------+
int OnInit()
{
   emaFastHandle = iMA(_Symbol, PERIOD_M15, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, PERIOD_M15, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_M15, ATR_Period);

   if(emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("Indicator handle error. fast=", emaFastHandle,
            " slow=", emaSlowHandle, " atr=", atrHandle);
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);

   // Initialize daily tracking
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   currentDay = dt.day;
   dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime t = iTime(_Symbol, PERIOD_M15, 0);
   if(t == 0) return false;
   if(t != lastBarTime)
   {
      lastBarTime = t;
      tradesThisBar = 0;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManageRunner();
   CleanupPartialTracker();

   // Drawdown cutoff check
   if(!IsDrawdownOK())
   {
      static bool warnedDD = false;
      if(!warnedDD)
      {
         Print("DAILY DRAWDOWN LIMIT REACHED. Trading halted for today.");
         warnedDD = true;
      }
      return;
   }

   if(!IsNewBar()) return;
   if(tradesThisBar >= MaxTradesPerBar) return;
   if(!IsSpreadOK()) return;
   if(!IsSessionOK()) return;
   if(CountMyPositions() > 0) return;

   if(Bars(_Symbol, PERIOD_M15) < MathMax(EMA_Slow + 5, 250))
      return;

   // Copy indicator data
   double fast[3], slow[3], atr[1];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(atr, true);

   int cf = CopyBuffer(emaFastHandle, 0, 0, 3, fast);
   int cs = CopyBuffer(emaSlowHandle, 0, 0, 3, slow);
   int ca = CopyBuffer(atrHandle, 0, 0, 1, atr);

   if(cf < 3 || cs < 3 || ca < 1)
   {
      Print("CopyBuffer failed. fast=", cf, " slow=", cs, " atr=", ca,
            " err=", GetLastError());
      return;
   }

   // Use closed candle (shift 1)
   double close1 = iClose(_Symbol, PERIOD_M15, 1);
   double high2  = iHigh(_Symbol, PERIOD_M15, 2);
   double low2   = iLow(_Symbol, PERIOD_M15, 2);

   bool bullish = (close1 > slow[1] && fast[1] > slow[1]);
   bool bearish = (close1 < slow[1] && fast[1] < slow[1]);

   bool breakUp = (close1 > high2);
   bool breakDn = (close1 < low2);

   if(bullish && breakUp)
   {
      OpenTrade(ORDER_TYPE_BUY, atr[0]);
      tradesThisBar++;
   }
   else if(bearish && breakDn)
   {
      OpenTrade(ORDER_TYPE_SELL, atr[0]);
      tradesThisBar++;
   }
}

//+------------------------------------------------------------------+
bool BuildStops(ENUM_ORDER_TYPE type, double price, double atrVal, double &sl, double &tp, double &slPips)
{
   double pip = PipSize();
   int stopLevelPts = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopLevelPts * _Point;

   if(UseATRStops && atrVal > 0)
   {
      slPips = atrVal * ATR_SL_Multiplier / pip;
      double tpPips = atrVal * ATR_TP_Multiplier / pip;

      if(type == ORDER_TYPE_BUY)
      {
         sl = price - slPips * pip;
         tp = price + tpPips * pip;
      }
      else
      {
         sl = price + slPips * pip;
         tp = price - tpPips * pip;
      }
   }
   else
   {
      slPips = (double)StopLoss_Pips;
      if(type == ORDER_TYPE_BUY)
      {
         sl = price - StopLoss_Pips * pip;
         tp = price + TakeProfit_Pips * pip;
      }
      else
      {
         sl = price + StopLoss_Pips * pip;
         tp = price - TakeProfit_Pips * pip;
      }
   }

   // Enforce minimum stop distance
   if(type == ORDER_TYPE_BUY)
   {
      if((price - sl) < minDist) sl = price - minDist;
      if((tp - price) < minDist) tp = price + minDist;
   }
   else
   {
      if((sl - price) < minDist) sl = price + minDist;
      if((price - tp) < minDist) tp = price - minDist;
   }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   return true;
}

//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double atrVal)
{
   double price = (type == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl = 0.0, tp = 0.0, slPips = 0.0;
   BuildStops(type, price, atrVal, sl, tp, slPips);

   double vol = GetATRBasedLot(slPips);

   bool ok = false;
   if(type == ORDER_TYPE_BUY)
      ok = trade.Buy(vol, _Symbol, 0.0, sl, tp, "SniperRunner v2");
   else
      ok = trade.Sell(vol, _Symbol, 0.0, sl, tp, "SniperRunner v2");

   if(!ok)
   {
      Print("Trade failed. retcode=", trade.ResultRetcode(),
            " desc=", trade.ResultRetcodeDescription(),
            " lastErr=", GetLastError());
   }
   else
   {
      Print("Trade opened. ticket=", trade.ResultOrder(),
            " vol=", vol, " sl=", sl, " tp=", tp,
            " atr=", atrVal);
   }
}

//+------------------------------------------------------------------+
void ManageRunner()
{
   double pip = PipSize();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long mg    = PositionGetInteger(POSITION_MAGIC);
      if(sym != _Symbol || mg != MagicNumber) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl        = PositionGetDouble(POSITION_SL);
      double tp        = PositionGetDouble(POSITION_TP);
      double volume    = PositionGetDouble(POSITION_VOLUME);

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double profitPips = 0.0;
      if(type == POSITION_TYPE_BUY)
         profitPips = (bid - openPrice) / pip;
      else
         profitPips = (openPrice - ask) / pip;

      // === BREAKEVEN ===
      if(profitPips >= Breakeven_Pips)
      {
         double be = NormalizeDouble(openPrice, _Digits);
         bool needBE = false;

         if(type == POSITION_TYPE_BUY)
            needBE = (sl < be);
         else
            needBE = (sl > be || sl == 0.0);

         if(needBE)
         {
            if(!trade.PositionModify(ticket, be, tp))
            {
               Print("BE modify failed. ticket=", ticket,
                     " retcode=", trade.ResultRetcode(),
                     " desc=", trade.ResultRetcodeDescription());
            }
         }
      }

      // === PARTIAL CLOSE ===
      if(profitPips >= PartialClose_Pips && !IsPartialDone(ticket))
      {
         double closeVolume = NormalizeVolume(volume * PartialClosePercent);

         double vMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double vStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

         if(closeVolume >= vMin && (volume - closeVolume) >= vMin - (vStep * 0.5))
         {
            if(trade.PositionClosePartial(ticket, closeVolume))
            {
               MarkPartialDone(ticket);
               Print("Partial close done. ticket=", ticket, " closed=", closeVolume);
            }
            else
            {
               Print("Partial close failed. ticket=", ticket,
                     " retcode=", trade.ResultRetcode(),
                     " desc=", trade.ResultRetcodeDescription());
            }
         }
         else
         {
            MarkPartialDone(ticket);
            Print("Partial skipped (volume constraints). ticket=", ticket);
         }
      }
   }
}
