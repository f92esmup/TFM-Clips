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
// PARÁMETROS DE ENTRADA (Inputs)
// ========================================================================
input int    InpThrBase     = 3;   // Umbral Base Nivel 1 (Votos Netos)
input int    InpThrStep     = 3;   // Incremento de Votos por Nivel
input int    InpHysteresis  = 2;   // Histéresis (Tolerancia anti-comisiones)

input double InpBaseRisk    = 0.5; // Riesgo Base Nivel 1 (%)
input double InpRiskInc     = 0.5; // Incremento por Nivel (%)

// Filtro de Volatilidad (ATR Ancla en H1)
input int    InpAtrPeriod = 14;        
input double InpAtrMultiplier = 3.0;   // Multiplicador ancho (Disaster Stop) para ceder control al Enjambre

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
   GestorRiesgo = new CRiskManager(InpThrBase, InpThrStep, InpHysteresis, InpBaseRisk, InpRiskInc);
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
   
   for(int i=0; i<10; i++) ObjectDelete(0, "HUD_LINE_" + IntegerToString(i));
   Comment("");
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
      Clips.Eval("(focus MACRO MICRO DECISION)"); // <--- EL ESMERILADO MÁGICO: Sin esto los submódulos nunca se ejecutaban
      Clips.Run();
      
      string voto = Clips.GetStr("(obtener-voto)"); 
      GestorRiesgo.UpdateAgentVote(id, voto);
      
      hubo_actualizacion = true;
      procesados++;
     }

   // ========================================================================
   // 3. VERIFICACIÓN DE ESTADO (CALENTAMIENTO)
   // ========================================================================
   int required_bars = InpHistorySize; // VWAP necesita InpHistorySize velas
   int current_bars = Feeds[15].GetAvailableBars(); // Miramos el feed más lento
   bool is_system_ready = (current_bars >= required_bars);

   // ========================================================================
   // 4. MOTOR DE EJECUCIÓN (NETTING)
   // ========================================================================
   // Solo ejecutamos si el sistema está caliente, hubo actualización y la cola está vacía
   if(is_system_ready && hubo_actualizacion && ColaTareas.IsEmpty())
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

      // 2. Leer Exposición Actual (Soporte Multi-Ticket para Hedging)
      double current_lot = 0.0;
      for(int i = 0; i < PositionsTotal(); i++)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               current_lot -= PositionGetDouble(POSITION_VOLUME);
            else
               current_lot += PositionGetDouble(POSITION_VOLUME);
           }
        }

      // 3. Normalizar
      double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      target_lot = MathFloor(target_lot / vol_step) * vol_step;
      double lot_delta = target_lot - current_lot;

      // 4. Ejecutar Scale-In / Scale-Out (Compatible con Hedging)
      if(MathAbs(lot_delta) >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
         PrintFormat(">>> INTENTO EJECUCIÓN: Consenso=%d | NivelRiesgo=%d | LoteDeseado=%.2f | LoteActual=%.2f | Delta=%.2f | SL_pips=%.1f", 
                     GestorRiesgo.GetNetVotes(), GestorRiesgo.GetCurrentLevel(), target_lot, current_lot, lot_delta, sl_dist / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
         
         if(lot_delta > 0)
           {
            // SCALE-IN
            if(!Trade.Buy(lot_delta, _Symbol, ask, bid - sl_dist, 0, "MultiAgente: Scale-In"))
               Print("!!! ERROR EN TRADE.BUY: ", GetLastError(), " | SL=", bid - sl_dist);
            else
               Print(">>> SCALE-IN COMPLETADO: ", lot_delta, " lotes.");
           }
         else if(lot_delta < 0)
           {
            // SCALE-OUT / CLOSE
            Print(">>> INICIANDO SCALE-OUT. Cerrando tickets antiguos...");
            for(int i = PositionsTotal() - 1; i >= 0; i--)
              {
               ulong ticket = PositionGetTicket(i);
               if(PositionGetString(POSITION_SYMBOL) == _Symbol) 
                 {
                  if(!Trade.PositionClose(ticket))
                     Print("!!! ERROR AL CERRAR TICKET ", ticket, " Error: ", GetLastError());
                 }
              }
            
            if(target_lot > 0)
              {
               if(!Trade.Buy(target_lot, _Symbol, ask, bid - sl_dist, 0, "MultiAgente: Scale-Out Sync"))
                  Print("!!! ERROR EN RECOMPRA SCALE-OUT: ", GetLastError());
               else
                  Print(">>> RECOMPRA SCALE-OUT COMPLETADA: ", target_lot, " lotes.");
              }
           }
        }
     }
      
    // ========================================================================
    // 5. HUD (PANEL DE VISUALIZACIÓN EN GRÁFICO INFERIOR IZQUIERDO)
    // ========================================================================
    string status_msg = is_system_ready ? "[ONLINE] LISTO PARA OPERAR" : StringFormat("[LOAD] RECOPILANDO DATOS (%d/%d)", current_bars, required_bars);

    double exposure = 0.0;
    if(PositionSelect(_Symbol))
      {
       exposure = PositionGetDouble(POSITION_VOLUME);
       if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) exposure = -exposure;
      }
      
    int v_buy, v_reduce, v_wait;
    GestorRiesgo.GetVoteCounts(v_buy, v_reduce, v_wait);
      
    string lineas[9];
    lineas[0] = "=================================================";
    lineas[1] = "            CEREBRO MULTIAGENTE TFM              ";
    lineas[2] = "=================================================";
    lineas[3] = StringFormat(" Estado: %s", status_msg);
    lineas[4] = "-------------------------------------------------";
    lineas[5] = StringFormat(" Votos: [⬆️ Comprar: %02d | ⬇️ Reducir: %02d | ⏸️ Esperar: %02d]", v_buy, v_reduce, v_wait);
    lineas[6] = StringFormat(" Consenso Neto: %+d votos", GestorRiesgo.GetNetVotes());
    lineas[7] = StringFormat(" Nivel Riesgo: %d | Lotes Exposición: %.2f", GestorRiesgo.GetCurrentLevel(), exposure);
    lineas[8] = "=================================================";
    
    for(int i=0; i<9; i++)
      {
       string obj_name = "HUD_LINE_" + IntegerToString(i);
       if(ObjectFind(0, obj_name) < 0)
         {
          ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
          ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
          ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, 20);
          // La línea 0 es la superior del bloque, la 8 es la más baja.
          ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, 20 + (9 - i - 1) * 15);
          ObjectSetString(0, obj_name, OBJPROP_FONT, "Courier New");
          ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 10);
          ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrLime);
          ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
         }
       ObjectSetString(0, obj_name, OBJPROP_TEXT, lineas[i]);
      }
   }
//+------------------------------------------------------------------+