//+------------------------------------------------------------------+
//|                                           RangeFilterSignals.mq5 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Free indicator: the range filter on closed bars. A line that     |
//| moves only when price travels more than the smoothed average     |
//| range away from it, two bands at +/- that range, and an arrow    |
//| with an alert when a buy setup follows a sell setup (or the      |
//| reverse). Engine: Include/RangeFilter/RF.mqh.                    |
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
#property description "Range filter line, bands and buy/sell arrows with alerts, on closed bars only."
#property description "The line moves only when price travels further than the smoothed average range."
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   5
#property indicator_label1  "Buy"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  C'38,166,98'
#property indicator_width1  2
#property indicator_label2  "Sell"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  C'226,74,70'
#property indicator_width2  2
#property indicator_label3  "Range filter"
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  C'38,166,98',C'226,74,70',C'150,160,175'
#property indicator_width3  2
#property indicator_label4  "Upper band"
#property indicator_type4   DRAW_LINE
#property indicator_color4  C'90,100,115'
#property indicator_style4  STYLE_DOT
#property indicator_label5  "Lower band"
#property indicator_type5   DRAW_LINE
#property indicator_color5  C'90,100,115'
#property indicator_style5  STYLE_DOT

#include <RangeFilter/RF.mqh>

input group "Range filter"
input int    InpPeriod    = 100;      // Sampling period
input double InpMult      = 3.0;      // Range multiplier
input bool   InpBands     = true;     // Draw the bands
input group "Display"
input int    InpHistory   = 3000;     // Closed bars to calculate (300-50000)

#include <RangeFilter/SignalAlerts.mqh>

const string PRODUCT="Range Filter Signals";

double   b_buy[],b_sell[],b_filt[],b_clr[],b_hi[],b_lo[],b_side[],b_range[],b_cond[];
RFParams g_p;
RFState  g_s;
int      g_start=0,g_fed=0;
datetime g_alert_bar=0;

int OnInit()
  {
   if(InpPeriod<2 || InpPeriod>1000 || InpMult<=0 || InpHistory<300 || InpHistory>50000)
     {
      Print(PRODUCT,": period 2-1000, multiplier above 0, history 300-50000");
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_p.period=InpPeriod;
   g_p.mult=InpMult;
   SetIndexBuffer(0,b_buy,INDICATOR_DATA);
   SetIndexBuffer(1,b_sell,INDICATOR_DATA);
   SetIndexBuffer(2,b_filt,INDICATOR_DATA);
   SetIndexBuffer(3,b_clr,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4,b_hi,INDICATOR_DATA);
   SetIndexBuffer(5,b_lo,INDICATOR_DATA);
   SetIndexBuffer(6,b_side,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,b_range,INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,b_cond,INDICATOR_CALCULATIONS);
   PlotIndexSetInteger(0,PLOT_ARROW,233);
   PlotIndexSetInteger(1,PLOT_ARROW,234);
   PlotIndexSetInteger(0,PLOT_ARROW_SHIFT,15);
   PlotIndexSetInteger(1,PLOT_ARROW_SHIFT,-15);
   if(!InpBands)
     {
      PlotIndexSetInteger(3,PLOT_DRAW_TYPE,DRAW_NONE);
      PlotIndexSetInteger(4,PLOT_DRAW_TYPE,DRAW_NONE);
     }
   for(int i=0; i<5; i++)
      PlotIndexSetDouble(i,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME,StringFormat("Range Filter (%d, %.1f)",InpPeriod,InpMult));
   RFInit(g_s);
   g_fed=0;
   return(INIT_SUCCEEDED);
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
  {
   if(rates_total<10)
      return(0);
   if(prev_calculated==0)
     {
      RFInit(g_s);
      g_fed=0;
      g_start=MathMax(0,rates_total-1-InpHistory);
      ArrayInitialize(b_buy,EMPTY_VALUE); ArrayInitialize(b_sell,EMPTY_VALUE); ArrayInitialize(b_filt,EMPTY_VALUE);
      ArrayInitialize(b_clr,2); ArrayInitialize(b_hi,EMPTY_VALUE); ArrayInitialize(b_lo,EMPTY_VALUE);
      ArrayInitialize(b_side,EMPTY_VALUE); ArrayInitialize(b_range,EMPTY_VALUE); ArrayInitialize(b_cond,EMPTY_VALUE);
     }
   else
      for(int i=MathMax(prev_calculated-1,g_start+g_fed); i<rates_total; i++)
        {
         b_buy[i]=EMPTY_VALUE; b_sell[i]=EMPTY_VALUE; b_filt[i]=EMPTY_VALUE; b_clr[i]=2; b_hi[i]=EMPTY_VALUE;
         b_lo[i]=EMPTY_VALUE; b_side[i]=EMPTY_VALUE; b_range[i]=EMPTY_VALUE; b_cond[i]=EMPTY_VALUE;
        }
   bool live=(prev_calculated>0);
   for(int i=g_start+g_fed; i<=rates_total-2; i++)
     {
      bool ev=RFFeed(g_s,g_p,close[i]);
      g_fed++;
      if(g_s.filt!=EMPTY_VALUE)
        {
         b_filt[i]=g_s.filt;
         int side=RFSide(g_s);
         b_clr[i]=(side>0 ? 0 : (side<0 ? 1 : 2));
         b_hi[i]=g_s.filt+g_s.range;
         b_lo[i]=g_s.filt-g_s.range;
         b_side[i]=side;
         b_range[i]=g_s.range;
         b_cond[i]=g_s.cond;
        }
      if(!ev)
         continue;
      if(g_s.ev>0)
         b_buy[i]=low[i];
      else
         b_sell[i]=high[i];
      if(live && i==rates_total-2 && time[i]>g_alert_bar)
        {
         g_alert_bar=time[i];
         SignalAlertMessage(PRODUCT,StringFormat("%s on %s %s at %s",g_s.ev>0 ? "BUY" : "SELL",_Symbol,
                            StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7),DoubleToString(close[i],_Digits)));
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
