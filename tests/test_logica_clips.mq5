//+------------------------------------------------------------------+
//|                                           test_logica_clips.mq5  |
//|                                  Copyright 2026, Pedro Escudero. |
//+------------------------------------------------------------------+
#property strict

#include <tfm\clips.mqh>

// Helper para ejecutar un escenario e imprimir el resultado
void TestScenario(CClipsEngine &clips, string name, string facts, string expected)
  {
   clips.Reset(); 
   clips.Eval(facts); 
   clips.Eval("(focus MACRO MICRO DECISION)"); 
   clips.Run(); 
   
   string query = "(obtener-voto)";
   string result = clips.GetStr(query);
   
   string status = (result == expected) ? "PASS" : "FAIL";
   PrintFormat("TEST: %s", name);
   PrintFormat("--> Esperado: %s | Obtenido: %s | [%s]", expected, result, status);
   Print("--------------------------------------------------");
  }

void OnStart()
  {
   CClipsEngine clips;
   
   if(!clips.IsReady())
     {
      Print("Error: No se pudo inicializar la DLL de CLIPS.");
      return;
     }

   string path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\";
   
   if(!clips.Load(path + "00_templates.clp") ||
      !clips.Load(path + "01_macro.clp") ||
      !clips.Load(path + "02_micro.clp") ||
      !clips.Load(path + "03_decision.clp"))
     {
      Print("Error: No se pudieron cargar los archivos .clp.");
      Print(clips.GetLastError());
      return;
     }
     
   Print("Ejecutando batería de pruebas exhaustivas con Hiperparámetros Dinámicos...");
   Print("==================================================");

   // Cadena base con el "ADN" del agente para que las reglas tengan contra qué comparar
   string hp = "(hiperparametros (rsi-sobrecompra 70.0) (rsi-sobreventa 30.0) (atr-expansion 1.5) (atr-contraccion 0.8) (vwap-desviacion 2.0) (alma-pendiente 0.001) (pinbar-ratio-larga 2.5) (pinbar-ratio-corta 0.5) (envolvente-ratio 1.2) (bos-margen 0.0) (insidebar-ratio 0.8)) ";

   // ========================================================================
   // CASO 1: COMPRA CLÁSICA (Tendencia + Volatilidad + Pin Bar Alcista)
   // ========================================================================
   string facts1 = "(assert " + hp + 
                   "        (indicador (nombre ALMA) (valor 1.5))" +
                   "        (indicador (nombre ATR) (valor 2.0))" +
                   "        (vela (id 0) (open 10.0) (close 11.0) (high 11.2) (low 5.0)))";
   TestScenario(clips, "1. Compra por Pin Bar Alcista", facts1, "comprar");

   // ========================================================================
   // CASO 2: REDUCIR POR AGOTAMIENTO (Sobrecompra + Envolvente Bajista)
   // ========================================================================
   string facts2 = "(assert " + hp + 
                   "        (indicador (nombre RSI) (valor 85.0))" +
                   "        (vela (id 1) (open 10.0) (close 11.0) (high 11.5) (low 9.5))" +
                   "        (vela (id 0) (open 11.5) (close 9.0) (high 12.0) (low 8.5)))";
   TestScenario(clips, "2. Reducir por Envolvente Bajista", facts2, "reducir");

   // ========================================================================
   // CASO 3: REDUCIR POR COMPRESIÓN (VWAP Alejado + Inside Bar)
   // ========================================================================
   string facts3 = "(assert " + hp + 
                   "        (indicador (nombre VWAP) (valor 2.5))" +
                   "        (vela (id 1) (open 10.0) (close 10.0) (high 15.0) (low 5.0))" +
                   "        (vela (id 0) (open 10.0) (close 10.0) (high 12.0) (low 8.0)))";
   TestScenario(clips, "3. Reducir por Compresión de Volatilidad", facts3, "reducir");

   // ========================================================================
   // CASO 4: VENTANA LARGA - BoS Alcista (10 Velas) + Macro Neutro = Esperar
   // ========================================================================
   string facts4 = "(assert " + hp + 
                   "        (indicador (nombre RSI) (valor 50.0))" +
                   "        (vela (id 9) (high 10.0)) (vela (id 8) (high 10.5))" +
                   "        (vela (id 7) (high 11.0)) (vela (id 6) (high 10.8))" +
                   "        (vela (id 5) (high 11.2)) (vela (id 4) (high 10.9))" +
                   "        (vela (id 3) (high 11.5)) (vela (id 2) (high 11.1))" +
                   "        (vela (id 1) (high 11.8)) (vela (id 0) (close 12.0)))";
   TestScenario(clips, "4. BoS Alcista Extenso sin confirmación Macro", facts4, "esperar");

   // ========================================================================
   // CASO 5: COMPRA - Envolvente Alcista
   // ========================================================================
   string facts5 = "(assert " + hp + 
                   "        (indicador (nombre ALMA) (valor 1.0))" +
                   "        (indicador (nombre ATR) (valor 1.8))" +
                   "        (vela (id 1) (open 11.0) (close 10.0))" +
                   "        (vela (id 0) (open 9.5) (close 12.0)))";
   TestScenario(clips, "5. Compra por Envolvente Alcista", facts5, "comprar");

   // ========================================================================
   // CASO 6: VENTANA MEDIA - BoS Bajista (6 Velas) + Sobrecompra = Reducir
   // ========================================================================
   string facts6 = "(assert " + hp + 
                   "        (indicador (nombre RSI) (valor 80.0))" +
                   "        (vela (id 5) (low 10.0)) (vela (id 4) (low 10.5))" +
                   "        (vela (id 3) (low 9.8))  (vela (id 2) (low 9.5))" +
                   "        (vela (id 1) (low 9.2))  (vela (id 0) (close 9.0)))";
   TestScenario(clips, "6. Reducir por BoS Bajista Extenso", facts6, "reducir");

   // ========================================================================
   // CASO 7: PIN BAR BAJISTA + Sobrecompra = Reducir
   // ========================================================================
   string facts7 = "(assert " + hp + 
                   "        (indicador (nombre RSI) (valor 75.0))" +
                   "        (vela (id 0) (open 10.0) (close 9.0) (high 15.0) (low 8.5)))";
   TestScenario(clips, "7. Reducir por Pin Bar Bajista", facts7, "reducir");

   // ========================================================================
   // CASO 8: CASO RARO - Múltiples Patrones (Pin Bar Y BoS simultáneos)
   // ========================================================================
   string facts8 = "(assert " + hp + 
                   "        (indicador (nombre ALMA) (valor 2.0))" +
                   "        (indicador (nombre ATR) (valor 2.0))" +
                   "        (vela (id 3) (high 15.0)) (vela (id 2) (high 14.0))" +
                   "        (vela (id 1) (high 13.0))" +
                   "        (vela (id 0) (open 14.0) (close 16.0) (high 16.5) (low 8.0)))";
   TestScenario(clips, "8. Patrón Múltiple (Pin Bar + BoS)", facts8, "comprar");

   // ========================================================================
   // CASO 9: RUIDO ABSOLUTO (3 Velas normales) = Esperar
   // ========================================================================
   string facts9 = "(assert " + hp + 
                   "        (indicador (nombre ALMA) (valor 0.5))" +
                   "        (indicador (nombre ATR) (valor 1.0))" +
                   "        (vela (id 2) (open 10.0) (close 10.5) (high 11.0) (low 9.0))" +
                   "        (vela (id 1) (open 10.5) (close 11.0) (high 11.5) (low 10.0))" +
                   "        (vela (id 0) (open 11.0) (close 11.2) (high 11.8) (low 10.8)))";
   TestScenario(clips, "9. Ruido puro sin estructura", facts9, "esperar");

   // ========================================================================
   // CASO 10: CONFLICTO MACRO/MICRO (Fallback / Safety Net) = Esperar
   // ========================================================================
   string facts10 = "(assert " + hp + 
                    "        (indicador (nombre ALMA) (valor -1.5))" +
                    "        (indicador (nombre ATR) (valor 2.0))" +
                    "        (vela (id 0) (open 10.0) (close 11.0) (high 11.2) (low 5.0)))";
   TestScenario(clips, "10. Conflicto de tendencias (Safety Net)", facts10, "esperar");
  }
//+------------------------------------------------------------------+