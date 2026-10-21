//+------------------------------------------------------------------+
//|                                           RangeFilterSignals.mq4 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| MT4 edition of Range Filter Signals: the same engine (RF.mqh, an |
//| exact copy of the MT5 Include/RangeFilter/RF.mqh) on closed bars.|
//| A line that moves only when price travels more than the smoothed |
//| average range away from it, two bands at +/- that range, and an  |
//| arrow with an alert when a buy setup follows a sell setup (or    |
//| the reverse).                                                    |
//| MT4 differences: the line is three buffers (rising, falling,     |
//| flat), and the arrows sit a fraction of ATR(14) away from the    |
//| candle (MT4 has no pixel shift).                                 |
//| Buffers for iCustom match MT5 where they can: 0 buy, 1 sell,     |
//| 2 filter, 4 upper band, 5 lower band.                            |
//+------------------------------------------------------------------+
// Licence: Mozilla Public License 2.0. This Source Code Form is subject
// to the terms of the MPL, v. 2.0. If a copy of the MPL was not
// distributed with this file, You can obtain one at
// https://mozilla.org/MPL/2.0/
// Origin: the range-filter method is popularised by TradingView open-source
// scripts, notably "Range Filter [DW]" (the initials are the author's) and its
// variants. This file is an independent MQL implementation of the published method.
// SPDX-License-Identifier: MPL-2.0
#property copyright "Copyright 2026, Allan Niñal <https://www.allanninal.dev/mql5>"
#property link      "https://www.allanninal.dev/mql5"
#property version   "1.00"
#property strict
#property description "Range filter line, bands and buy/sell arrows with alerts, on closed bars only."
#property description "The line moves only when price travels further than the smoothed average range."
#property indicator_chart_window
#property indicator_buffers 11
#property indicator_color1  C'38,166,98'
#property indicator_width1  2
#property indicator_color2  C'226,74,70'
#property indicator_width2  2
#property indicator_color3  clrNONE
#property indicator_color4  C'38,166,98'
#property indicator_width4  2
#property indicator_color5  C'90,100,115'
#property indicator_color6  C'90,100,115'
#property indicator_color10 C'226,74,70'
#property indicator_width10 2
#property indicator_color11 C'150,160,175'
#property indicator_width11 2

#include "RF.mqh"

input int    InpPeriod    = 100;      // Sampling period
input double InpMult      = 3.0;      // Range multiplier
input bool   InpBands     = true;     // Draw the bands
input int    InpHistory   = 3000;     // Closed bars to calculate (300-50000)
input double InpArrowGap  = 0.3;      // Arrow distance from the candle (x ATR)

#include "SignalAlerts.mqh"

const string PRODUCT="Range Filter Signals";

//--- series-indexed (0 = live bar), as every MT4 buffer
double   b_buy[],b_sell[],b_filt[],b_rise[],b_hi[],b_lo[],b_side[],b_range[],b_cond[],b_fall[],b_flat[];
RFParams g_p;
RFState  g_s;
int      g_start=0,g_fed=0;            // oldest-based index of the first bar fed, bars fed so far
datetime g_alert_bar=0;

int OnInit()
  {
   if(InpPeriod<2 || InpPeriod>1000 || InpMult<=0 || InpHistory<300 || InpHistory>50000 || InpArrowGap<0)
     {
      Print(PRODUCT,": period 2-1000, multiplier above 0, history 300-50000");
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_p.period=InpPeriod;
   g_p.mult=InpMult;
   SetIndexBuffer(0,b_buy);
   SetIndexBuffer(1,b_sell);
   SetIndexBuffer(2,b_filt);
   SetIndexBuffer(3,b_rise);
   SetIndexBuffer(4,b_hi);
   SetIndexBuffer(5,b_lo);
   SetIndexBuffer(6,b_side);
   SetIndexBuffer(7,b_range);
   SetIndexBuffer(8,b_cond);
   SetIndexBuffer(9,b_fall);
   SetIndexBuffer(10,b_flat);
   SetIndexStyle(0,DRAW_ARROW);
   SetIndexStyle(1,DRAW_ARROW);
   SetIndexArrow(0,233);
   SetIndexArrow(1,234);
   SetIndexStyle(2,DRAW_NONE);
   SetIndexStyle(3,DRAW_LINE);
   SetIndexStyle(9,DRAW_LINE);
   SetIndexStyle(10,DRAW_LINE);
   SetIndexStyle(4,InpBands ? DRAW_LINE : DRAW_NONE,STYLE_DOT);
   SetIndexStyle(5,InpBands ? DRAW_LINE : DRAW_NONE,STYLE_DOT);
   for(int b=6; b<=8; b++)
      SetIndexStyle(b,DRAW_NONE);
   SetIndexLabel(0,"Buy");
   SetIndexLabel(1,"Sell");
   SetIndexLabel(2,"Range filter");
   SetIndexLabel(4,"Upper band");
   SetIndexLabel(5,"Lower band");
   for(int b=0; b<11; b++)
     {
      SetIndexEmptyValue(b,EMPTY_VALUE);
      if(b==3 || b>=6)
         SetIndexLabel(b,NULL);
     }
   IndicatorShortName(StringFormat("Range Filter (%d, %.1f)",InpPeriod,InpMult));
   IndicatorDigits(_Digits);
   RFInit(g_s);
   g_fed=0;
   return(INIT_SUCCEEDED);
  }

//--- empty every buffer at series index s
void Clear(const int s)
  {
   b_buy[s]=EMPTY_VALUE; b_sell[s]=EMPTY_VALUE; b_filt[s]=EMPTY_VALUE; b_rise[s]=EMPTY_VALUE; b_hi[s]=EMPTY_VALUE;
   b_lo[s]=EMPTY_VALUE; b_side[s]=EMPTY_VALUE; b_range[s]=EMPTY_VALUE; b_cond[s]=EMPTY_VALUE; b_fall[s]=EMPTY_VALUE;
   b_flat[s]=EMPTY_VALUE;
  }

//--- the line part of colour `c` (0 rising, 1 falling, 2 flat) at series index s
void SetPart(const int c,const int s,const double v)
  {
   if(c==0)
      b_rise[s]=v;
   else
      if(c==1)
         b_fall[s]=v;
      else
         b_flat[s]=v;
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
  {
   if(rates_total<10)
      return(0);
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   if(prev_calculated==0)
     {
      RFInit(g_s);
      g_fed=0;
      g_start=MathMax(0,rates_total-1-InpHistory);
      for(int s=0; s<rates_total; s++)
         Clear(s);
     }
   else
      for(int s=rates_total-1-(g_start+g_fed); s>=0; s--)
         Clear(s);                                    // bars not fed yet, including the live bar
   bool live=(prev_calculated>0);
   //--- feed the closed bars not fed yet, oldest first (i counts from the oldest bar, s is the series index)
   for(int i=g_start+g_fed; i<=rates_total-2; i++)
     {
      int s=rates_total-1-i;
      bool ev=RFFeed(g_s,g_p,close[s]);
      g_fed++;
      if(g_s.filt!=EMPTY_VALUE)
        {
         b_filt[s]=g_s.filt;
         int side=RFSide(g_s);
         int c=(side>0 ? 0 : (side<0 ? 1 : 2));
         SetPart(c,s,g_s.filt);
         //--- join from the older bar in this bar's colour (as MT5 colours a segment by its newer bar)
         if(s+1<rates_total && b_filt[s+1]!=EMPTY_VALUE && b_side[s+1]!=EMPTY_VALUE)
           {
            int side1=(int)b_side[s+1];
            int c1=(side1>0 ? 0 : (side1<0 ? 1 : 2));
            if(c1!=c)
               SetPart(c,s+1,b_filt[s+1]);
           }
         b_hi[s]=g_s.filt+g_s.range;
         b_lo[s]=g_s.filt-g_s.range;
         b_side[s]=side;
         b_range[s]=g_s.range;
         b_cond[s]=g_s.cond;
        }
      if(!ev)
         continue;
      double gap=InpArrowGap*iATR(NULL,0,14,s);
      if(g_s.ev>0)
         b_buy[s]=low[s]-gap;
      else
         b_sell[s]=high[s]+gap;
      if(live && i==rates_total-2 && time[s]>g_alert_bar)
        {
         g_alert_bar=time[s];
         SignalAlertMessage(PRODUCT,StringFormat("%s on %s %s at %s",g_s.ev>0 ? "BUY" : "SELL",_Symbol,TfName(),
                            DoubleToString(close[s],_Digits)));
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
