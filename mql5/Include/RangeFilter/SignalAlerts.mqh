//+------------------------------------------------------------------+
//|                                                 SignalAlerts.mqh |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Alert helper of Range Filter Signals: one message to every       |
//| channel that is switched on (pop-up, sound, push, e-mail),       |
//| silent in the tester. The caller sends one per closed-bar signal.|
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property strict

input group "Alerts"
input bool   InpAlertPopup = true;          // Pop-up alert
input bool   InpAlertSound = false;         // Play a sound
input string InpSoundFile  = "alert.wav";   // Sound file (terminal Sounds folder)
input bool   InpAlertPush  = false;         // Push notification (set up MetaQuotes ID in Options)
input bool   InpAlertEmail = false;         // E-mail (set up in Options)

//--- send one message to every channel that is switched on
void SignalAlertMessage(const string product,const string msg)
  {
   if(MQLInfoInteger(MQL_TESTER) || msg=="")
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
