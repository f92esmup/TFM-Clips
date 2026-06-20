//+------------------------------------------------------------------+
//|                                        test_latencia_clips.mq5   |
//|                                  Copyright 2026, Pedro Escudero. |
//+------------------------------------------------------------------+
#property strict

#include <clips.mqh>

void OnStart()
  {
   CClipsEngine clips;
   
   if(!clips.IsReady())
     {
      Print("Error: No se pudo inicializar CLIPS.");
      return;
     }

   string path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\";
   if(!clips.Load(path + "00_templates.clp") ||
      !clips.Load(path + "01_macro.clp") ||
      !clips.Load(path + "02_micro.clp") ||
      !clips.Load(path + "03_decision.clp"))
     {
      Print("Error cargando archivos.");
      return;
     }
     
   Print("Iniciando prueba de estrés: 100 agentes simultáneos...");
   
   // Pre-construimos el string de datos para simular la inyección completa
   string hp = "(hiperparametros (rsi-sobrecompra 70.0) (rsi-sobreventa 30.0) (atr-expansion 1.5) (atr-contraccion 0.8) (vwap-desviacion 2.0) (alma-pendiente 0.001) (pinbar-ratio-larga 2.5) (pinbar-ratio-corta 0.5) (envolvente-ratio 1.2) (bos-margen 0.0) (insidebar-ratio 0.8)) ";
   string facts = "(assert " + hp + 
                  "        (indicador (nombre RSI) (valor 85.0))" +
                  "        (indicador (nombre ALMA) (valor 1.5))" +
                  "        (vela (id 1) (open 10.0) (close 11.0) (high 11.5) (low 9.5))" +
                  "        (vela (id 0) (open 11.5) (close 9.0) (high 12.0) (low 8.5)))";

   int total_agents = 100;
   
   // Marcamos el tiempo de inicio (en microsegundos)
   ulong start_time = GetMicrosecondCount();
   
   // Bucle de saturación (simulando 100 agentes pidiendo datos en el mismo tick)
   for(int i = 0; i < total_agents; i++)
     {
      clips.Reset(); 
      clips.Eval(facts); 
      clips.Eval("(focus MACRO MICRO DECISION)"); 
      clips.Run(); 
      
      // Extraemos el voto para forzar el ciclo completo de lectura
      string query = "(progn (bind ?res \"sin_voto\") (do-for-all-facts ((?v voto)) TRUE (bind ?res ?v:accion)) ?res)";
      string result = clips.GetStr(query);
     }
     
   // Marcamos el tiempo final
   ulong end_time = GetMicrosecondCount();
   
   // Cálculos de rendimiento
   double total_ms = (end_time - start_time) / 1000.0;
   double avg_ms_per_agent = total_ms / total_agents;
   
   Print("==================================================");
   PrintFormat("Tiempo total para %d agentes: %.3f milisegundos", total_agents, total_ms);
   PrintFormat("Tiempo medio por agente: %.3f milisegundos", avg_ms_per_agent);
   Print("==================================================");
   
   // Veredicto automático
   if(total_ms > 15.0)
     {
      Print("VEREDICTO: Latencia ALTA. Se requiere Time-Slicing (Cola de Tareas) para evitar pérdida de ticks.");
     }
   else
     {
      Print("VEREDICTO: Latencia BAJA. El bucle estándar síncrono es seguro.");
     }
  }
//+------------------------------------------------------------------+