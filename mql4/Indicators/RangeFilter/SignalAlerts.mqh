//+------------------------------------------------------------------+
//|                                                 SignalAlerts.mqh |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| MT4 edition of the Range Filter alert helper: one message to     |
//| every channel that is switched on (pop-up, sound, push, e-mail), |
//| silent in the tester. The caller sends one per closed-bar signal.|
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property strict

input bool   InpAlertPopup = true;          // Pop-up alert
input bool   InpAlertSound = false;         // Play a sound
input string InpSoundFile  = "alert.wav";   // Sound file (terminal Sounds folder)
input bool   InpAlertPush  = false;         // Push notification (set up MetaQuotes ID in Options)
input bool   InpAlertEmail = false;         // E-mail (set up in Options)

//--- chart timeframe as text (M15, H1, ...)
string TfName()
  {
   switch(_Period)
     {
      case PERIOD_M1:  return("M1");
      case PERIOD_M5:  return("M5");
      case PERIOD_M15: return("M15");
      case PERIOD_M30: return("M30");
      case PERIOD_H1:  return("H1");
      case PERIOD_H4:  return("H4");
      case PERIOD_D1:  return("D1");
      case PERIOD_W1:  return("W1");
      case PERIOD_MN1: return("MN1");
     }
   return("M"+IntegerToString(_Period));
  }

//--- send one message to every channel that is switched on
void SignalAlertMessage(const string product,const string msg)
  {
   if(IsTesting() || msg=="")
      return;
   string text=product+": "+msg;
   if(InpAlertPopup)
      Alert(text);
   if(InpAlertSound && InpSoundFile!="")
      PlaySound(InpSoundFile);
   if(InpAlertPush && TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
      SendNotification(StringSubstr(text,0,255));
   if(InpAlertEmail && TerminalInfoInteger(TERMINAL_EMAIL_ENABLED))
      SendMail(product,text);
  }
//+------------------------------------------------------------------+
