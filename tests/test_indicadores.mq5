//+------------------------------------------------------------------+
//|                                             test_indicadores.mq5 |
//+------------------------------------------------------------------+
#property strict
#include "velas.mqh"
#include "Indicadores.mqh"

void Check(string name, bool condition)
  {
   PrintFormat("TEST: %s | [%s]", name, condition ? "PASS" : "FAIL");
  }

void OnStart()
  {
   Print("=== INICIANDO TESTS: Indicadores (RSI Incremental) ===");
   
   // Buffer de 20 velas, cerrando a 1 tick por vela para acelerar el test
   CCustomFeed feed(20, 1);
   CRsiCustom rsi(&feed, 14, PRICE_CLOSE);

   // Test 1: Estado inicial
   Check("1. Indicador no listo al instanciar (Warm-up pendiente)", rsi.IsReady() == false);

   // Test 2: Inyección parcial
   for(int i = 0; i < 10; i++)
     {
      if(feed.UpdateTick(1.1000 + (i * 0.0010), 10)) rsi.CalculateOnClose();
     }
   Check("2. Indicador sigue inactivo con < 14 velas", rsi.IsReady() == false);

   // Test 3: Cumplimiento del período (Vela 14)
   for(int i = 10; i < 15; i++)
     {
      if(feed.UpdateTick(1.1000 + (i * 0.0010), 10)) rsi.CalculateOnClose();
     }
   Check("3. Indicador activa IsReady = true al alcanzar el período", rsi.IsReady() == true);

   // Test 4: Precisión matemática incremental
   // Hemps inyectado una tendencia puramente alcista (precios sumando 0.0010 por tick)
   // Por lo tanto, no hay Average Loss, el RSI debe dar 100.0 exacto.
   double val = rsi.GetValue();
   Check("4. Matemática incremental correcta (Tendencia pura = RSI 100)", val == 100.0);
   
   // Test 5: Comportamiento ante caída (Inyectamos un crash de precio)
   feed.UpdateTick(1.0500, 100); 
   rsi.CalculateOnClose();
   double crash_val = rsi.GetValue();
   Check("5. RSI reacciona a caída severa de precio", crash_val < 100.0 && crash_val > 0.0);
  }
//+------------------------------------------------------------------+