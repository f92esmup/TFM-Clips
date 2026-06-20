//+------------------------------------------------------------------+
//|                                              Bot_MultiAgente.mq5 |
//|                                  Copyright 2026, Pedro Escudero. |
//+------------------------------------------------------------------+
#property strict

#include "Ensamble.mqh"
#include "TaskQueue.mqh"
#include "velas.mqh"
#include "GestionRiesgo.mqh"
#include <clips.mqh>
#include <Trade\Trade.mqh>

// ========================================================================
// HIPERPARÁMETROS
// ========================================================================
input int    InpThrLevel1 = 60;        
input int    InpThrLevel2 = 75;        
input int    InpThrLevel3 = 90;        
input double InpBaseRisk  = 0.5;       
input double InpRiskInc   = 0.5;       
input double InpRatio1    = 2.0;       
input double InpRatio2    = 3.0;       
input double InpRatio3    = 4.0;       

// Filtro de Volatilidad (ATR Ancla en H1)
input int    InpAtrPeriod = 14;        
input double InpAtrMultiplier = 1.5;   

// Arquitectura de Sistema
input int    InpMaxAgentsPerTick = 3;  
input int    InpHistorySize = 50;     

// ========================================================================
// GLOBALES
// ========================================================================
CEnsembleManager  Ensamble;
CTaskQueue        ColaTareas;
CRiskManager* GestorRiesgo;
CClipsEngine      Clips;
CTrade            Trade;

CCustomFeed* Feeds[16]; 
int               AtrHandle; // Ancla nativa de MT5

// ========================================================================
// INIT / DEINIT
// ========================================================================
int OnInit()
  {
   GestorRiesgo = new CRiskManager(InpThrLevel1, InpThrLevel2, InpThrLevel3, InpBaseRisk, InpRiskInc, InpRatio1, InpRatio2, InpRatio3);
   Ensamble.InitializeEnsemble();

   string path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\";
   if(!Clips.IsReady() || !Clips.Load(path + "reglas_agentes.clp")) return INIT_FAILED;

   // Definimos los 16 universos (ejemplo base de ticks)
   for(int i = 0; i < 16; i++)
     {
      long limite_ticks = 100 * (i + 1); // Simplificación. Aquí defines tus M5, H1, etc.
      Feeds[i] = new CCustomFeed(InpHistorySize, limite_ticks); 
     }

   // Inicializamos el ATR Ancla siempre en H1
   AtrHandle = iATR(_Symbol, PERIOD_H1, InpAtrPeriod);
   if(AtrHandle == INVALID_HANDLE) return INIT_FAILED;

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   delete GestorRiesgo;
   for(int i = 0; i < 16; i++) delete Feeds[i];
   IndicatorRelease(AtrHandle);
  }

// ========================================================================
// BUCLE TICK
// ========================================================================
void OnTick()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // 1. DATA BRIDGE
   for(int i = 0; i < 16; i++)
     {
      if(Feeds[i].UpdateTick(bid, 1.0))
        {
         for(int agent_id = 0; agent_id < 100; agent_id++)
           {
            if(Ensamble.GetAgentFeedID(agent_id) == i) ColaTareas.Push(agent_id);
           }
        }
     }

   // 2. TIME-SLICING & CLIPS
   int procesados = 0;
   bool hubo_actualizacion = false;

   while(!ColaTareas.IsEmpty() && procesados < InpMaxAgentsPerTick)
     {
      int id = ColaTareas.Pop();
      int feed_id = Ensamble.GetAgentFeedID(id);
      
      string hecho_adn = Ensamble.GetAgentFactString(id);
      string hecho_datos = Feeds[feed_id].GetClipsFacts(InpHistorySize);
      
      Clips.Reset();
      Clips.Eval("(assert " + hecho_adn + " " + hecho_datos + ")"); 
      Clips.Run();
      
      string voto = Clips.GetStr("(voto)"); 
      GestorRiesgo.UpdateAgentVote(id, voto);
      
      hubo_actualizacion = true;
      procesados++;
     }

   // 3. MOTOR DE EJECUCIÓN (NETTING)
   if(hubo_actualizacion)
     {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      STradeParams params = GestorRiesgo.GetTradeParams(balance);
      
      // Obtener el ATR actual en H1
      double atr_arr[];
      if(CopyBuffer(AtrHandle, 0, 0, 1, atr_arr) <= 0) return;
      double sl_dist = atr_arr[0] * InpAtrMultiplier;
      
      // 1. Calcular Lote Deseado
      double target_lot = 0.0;
      if(params.risk_amount > 0.0)
        {
         double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         target_lot = params.risk_amount / (sl_dist * (tick_value / tick_size));
        }

      // 2. Leer Exposición Actual
      double current_lot = 0.0;
      if(PositionSelect(_Symbol))
        {
         current_lot = PositionGetDouble(POSITION_VOLUME);
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) current_lot = -current_lot;
        }

      // 3. Normalizar
      double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      target_lot = MathFloor(target_lot / vol_step) * vol_step;
      double lot_delta = target_lot - current_lot;

      // 4. Ejecutar Scale-In / Scale-Out
      if(MathAbs(lot_delta) >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
         if(lot_delta > 0)
           {
            double tp_price = ask + (sl_dist * params.take_profit_ratio);
            Trade.Buy(lot_delta, _Symbol, ask, bid - sl_dist, tp_price, "MultiAgente: Comprar");
           }
         else if(lot_delta < 0)
           {
            Trade.Sell(MathAbs(lot_delta), _Symbol, bid, 0, 0, "MultiAgente: Reducir");
           }
        }
     }
  }
//+------------------------------------------------------------------+