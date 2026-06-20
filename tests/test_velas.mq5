//+------------------------------------------------------------------+
//|                                                   test_velas.mq5 |
//+------------------------------------------------------------------+
#property strict
#include <tfm\velas.mqh>

void Check(string name, bool condition)
  {
   PrintFormat("TEST: %s | [%s]", name, condition ? "PASS" : "FAIL");
  }

void OnStart()
  {
   Print("=== INICIANDO TESTS: CCustomFeed ===");
   
   // Buffer de 5 velas de historial, cada vela se cierra cada 3 ticks
   CCustomFeed feed(5, 3);
   SCandle out_candle;

   // Test 1: Construcción OHLC (Tick 1 y 2)
   feed.UpdateTick(1.1000, 10); // Tick 1: Open=1.1000
   bool tick2_closes = feed.UpdateTick(1.1050, 15); // Tick 2: High=1.1050
   
   feed.GetCandle(0, out_candle);
   Check("1. Formación en curso (OHLC y volumen correctos)", 
         out_candle.open == 1.1000 && out_candle.high == 1.1050 && out_candle.volume == 25 && tick2_closes == false);

   // Test 2: Cierre de vela (Tick 3)
   bool tick3_closes = feed.UpdateTick(1.0950, 20); // Tick 3: Low=1.0950. Cierra vela.
   Check("2. Cierre disparado al alcanzar el límite de ticks", tick3_closes == true);

   // Test 3: Desplazamiento del id (Vela cerrada pasa al id 1)
   feed.GetCandle(1, out_candle);
   Check("3. Vela cerrada se mueve al histórico id 1", 
         out_candle.open == 1.1000 && out_candle.close == 1.0950 && out_candle.tick_count == 3);

   // Test 4: Nueva vela vacía (id 0)
   feed.GetCandle(0, out_candle);
   Check("4. Nueva vela en id 0 se resetea al precio de cierre previo", 
         out_candle.open == 1.0950 && out_candle.tick_count == 0);

   // Test 5: Índices fuera de rango (Seguridad)
   bool valid_index = feed.GetCandle(10, out_candle);
   Check("5. Solicitar índices fuera del buffer devuelve false", valid_index == false);

   // Test 6: Traducción LISP para el motor CLIPS
   // Pedimos extraer un histórico de 2 velas. Como la vela 0 se ignora, 
   // debería devolver solo la estructura de la vela 1 recién cerrada.
   string clips_facts = feed.GetClipsFacts(2);
   
   // Buscamos que incluya el ID correcto y el precio formateado a 5 decimales
   bool has_vela_1 = (StringFind(clips_facts, "(vela (id 1)") >= 0);
   bool has_open_price = (StringFind(clips_facts, "(open 1.10000)") >= 0);
   
   Check("6. Traducción a LISP formatea correctamente los hechos", has_vela_1 && has_open_price);
  }
//+------------------------------------------------------------------+