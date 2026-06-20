//+------------------------------------------------------------------+
//|                                              Bot_MultiAgente.mq5 |
//|                                  Copyright 2026, Pedro Escudero. |
//+------------------------------------------------------------------+
#property strict

// Archivos necesarios para el Strategy Tester
#property tester_file "00_templates.clp"
#property tester_file "01_macro.clp"
#property tester_file "02_micro.clp"
#property tester_file "03_decision.clp"

#include <tfm\Ensamble.mqh>
#include <tfm\TaskQueue.mqh>
#include <tfm\velas.mqh>
#include <tfm\Indicadores.mqh>
#include <tfm\GestionRiesgo.mqh>
#include <tfm\clips.mqh>
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
CRsiCustom*  RSI[16];
CAlmaCustom* ALMA[16];
CAtrCustom*  ATR[16];
CVwapCustom* VWAP[16];
int               AtrHandle; // Ancla nativa de MT5

// ========================================================================
// INIT / DEINIT
// ========================================================================
int OnInit()
  {
   GestorRiesgo = new CRiskManager(InpThrLevel1, InpThrLevel2, InpThrLevel3, InpBaseRisk, InpRiskInc, InpRatio1, InpRatio2, InpRatio3);
   Ensamble.InitializeEnsemble();

   string path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\";
   if(!Clips.IsReady()) return INIT_FAILED;
   if(!Clips.Load(path + "00_templates.clp")) return INIT_FAILED;
   if(!Clips.Load(path + "01_macro.clp")) return INIT_FAILED;
   if(!Clips.Load(path + "02_micro.clp")) return INIT_FAILED;
   if(!Clips.Load(path + "03_decision.clp")) return INIT_FAILED;

   // Definimos los 16 universos (ejemplo base de ticks)
   for(int i = 0; i < 16; i++)
     {
      long limite_ticks = 100 * (i + 1); // Simplificación. Aquí defines tus M5, H1, etc.
      Feeds[i] = new CCustomFeed(InpHistorySize, limite_ticks); 
      RSI[i] = new CRsiCustom(Feeds[i], 14);
      ALMA[i] = new CAlmaCustom(Feeds[i], 9);
      ATR[i] = new CAtrCustom(Feeds[i], 14);
      VWAP[i] = new CVwapCustom(Feeds[i], 50);
     }

   // Inicializamos el ATR Ancla siempre en H1
   AtrHandle = iATR(_Symbol, PERIOD_H1, InpAtrPeriod);
   if(AtrHandle == INVALID_HANDLE) return INIT_FAILED;

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   delete GestorRiesgo;
   for(int i = 0; i < 16; i++)
     {
      delete Feeds[i];
      delete RSI[i];
      delete ALMA[i];
      delete ATR[i];
      delete VWAP[i];
     }
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
         RSI[i].CalculateOnClose();
         ALMA[i].CalculateOnClose();
         ATR[i].CalculateOnClose();
         VWAP[i].CalculateOnClose();
         
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
      
      if(RSI[feed_id].IsReady())  hecho_datos += StringFormat("(indicador (nombre RSI) (valor %.2f)) ", RSI[feed_id].GetValue());
      if(ALMA[feed_id].IsReady()) hecho_datos += StringFormat("(indicador (nombre ALMA) (valor %.5f)) ", ALMA[feed_id].GetValue());
      if(ATR[feed_id].IsReady())  hecho_datos += StringFormat("(indicador (nombre ATR) (valor %.5f)) ", ATR[feed_id].GetValue());
      if(VWAP[feed_id].IsReady()) hecho_datos += StringFormat("(indicador (nombre VWAP) (valor %.2f)) ", VWAP[feed_id].GetValue());
      
      Clips.Reset();
      Clips.Eval("(assert " + hecho_adn + " " + hecho_datos + ")"); 
      Clips.Run();
      
      string voto = Clips.GetStr("(obtener-voto)"); 
      GestorRiesgo.UpdateAgentVote(id, voto);
      
      hubo_actualizacion = true;
      procesados++;
     }

   // 3. MOTOR DE EJECUCIÓN (NETTING)
   // Solo ejecutamos netting cuando toda la cola se haya vaciado en este tick
   if(hubo_actualizacion && ColaTareas.IsEmpty())
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