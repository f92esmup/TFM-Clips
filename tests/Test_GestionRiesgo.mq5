//+------------------------------------------------------------------+
//|                                           test_gestionriesgo.mq5 |
//+------------------------------------------------------------------+
#property strict
#include <tfm/GestionRiesgo.mqh>

void Check(string name, bool condition)
  {
   PrintFormat("TEST: %s | [%s]", name, condition ? "PASS" : "FAIL");
  }

void OnStart()
  {
   Print("=== INICIANDO TESTS: GestionRiesgo (Conteo Democrático) ===");
   
   // Configuramos el gestor con los siguientes parámetros de test:
   // Umbrales: T1=20, T2=50, T3=80
   // Riesgo: Base 1.0%, Incremento 0.5% (Niveles: 1.0%, 1.5%, 2.0%)
   // Ratios: R1=2.0, R2=3.0, R3=4.0
   CRiskManager riesgo(20, 50, 80, 1.0, 0.5, 2.0, 3.0, 4.0);
   
   double balance = 10000.0;
   STradeParams params;

   // Test 1: Estado inicial (0 votos)
   params = riesgo.GetTradeParams(balance);
   Check("1. Consenso 0 bloquea la operativa (Riesgo 0.0)", params.risk_amount == 0.0);

   // Test 2: Votos insuficientes (< T1)
   for(int i = 0; i < 15; i++) riesgo.UpdateAgentVote(i, "comprar");
   params = riesgo.GetTradeParams(balance);
   Check("2. Consenso 15 no supera T1 (Riesgo 0.0)", params.risk_amount == 0.0);

   // Test 3: Nivel 1 Alcanzado (T1=20)
   for(int i = 15; i < 25; i++) riesgo.UpdateAgentVote(i, "comprar");
   params = riesgo.GetTradeParams(balance);
   // Riesgo Base (1.0% de 10000 = 100.0) | Ratio Nivel 1 (2.0)
   Check("3. Consenso 25 activa Nivel 1 (1.0%, R2)", params.risk_amount == 100.0 && params.take_profit_ratio == 2.0);

   // Test 4: Nivel 2 Alcanzado (T2=50)
   for(int i = 25; i < 60; i++) riesgo.UpdateAgentVote(i, "comprar");
   params = riesgo.GetTradeParams(balance);
   // Nivel 2 (1.0% + 0.5% = 1.5% de 10000 = 150.0) | Ratio Nivel 2 (3.0)
   Check("4. Consenso 60 activa Nivel 2 (1.5%, R3)", params.risk_amount == 150.0 && params.take_profit_ratio == 3.0);

   // Test 5: Nivel 3 Alcanzado (T3=80)
   for(int i = 60; i < 90; i++) riesgo.UpdateAgentVote(i, "comprar");
   params = riesgo.GetTradeParams(balance);
   // Nivel 3 (1.0% + 1.0% = 2.0% de 10000 = 200.0) | Ratio Nivel 3 (4.0)
   Check("5. Consenso 90 activa Nivel 3 (2.0%, R4)", params.risk_amount == 200.0 && params.take_profit_ratio == 4.0);

   // Test 6: Cancelación de Votos (El sistema es neto)
   // Tenemos 90 de compra. Cambiamos a 25 de ellos a "reducir".
   // Quedan 65 compras y 25 reducir. Consenso Neto = 40.
   // 40 cae al Nivel 1 (T1=20, T2=50).
   for(int i = 0; i < 25; i++) riesgo.UpdateAgentVote(i, "reducir"); 
   params = riesgo.GetTradeParams(balance);
   Check("6. Votos bajistas cancelan alcistas (Neto 40 cae a Nivel 1)", params.risk_amount == 100.0 && params.take_profit_ratio == 2.0);
   
   // Test 7: Histéresis (Mantener nivel por inercia)
   // Reseteamos y subimos a Nivel 2 (T2=50)
   for(int i = 0; i < 100; i++) riesgo.UpdateAgentVote(i, "esperar");
   for(int i = 0; i < 55; i++) riesgo.UpdateAgentVote(i, "comprar");
   params = riesgo.GetTradeParams(balance); // Activa Nivel 2
   
   // Bajamos a 45 votos netos. T2=50, pero la tolerancia es T2-10 = 40.
   // Como 45 >= 40, debe mantener el Nivel 2 por inercia.
   for(int i = 45; i < 55; i++) riesgo.UpdateAgentVote(i, "esperar");
   params = riesgo.GetTradeParams(balance);
   Check("7. Histéresis mantiene Nivel 2 al caer a 45 (Tolerancia 40)", params.risk_amount == 150.0 && params.take_profit_ratio == 3.0);
   
   // Test 8: Datos ignorados
   riesgo.UpdateAgentVote(101, "comprar");
   params = riesgo.GetTradeParams(balance); 
   Check("8. Votos fuera de rango (ID 101) son ignorados", params.risk_amount == 150.0);
   }
//+------------------------------------------------------------------+