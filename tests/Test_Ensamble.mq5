//+------------------------------------------------------------------+
//|                                                test_ensamble.mq5 |
//+------------------------------------------------------------------+
#property strict
#include "Ensamble.mqh"

void Check(string name, bool condition)
  {
   PrintFormat("TEST: %s | [%s]", name, condition ? "PASS" : "FAIL");
  }

void OnStart()
  {
   Print("=== INICIANDO TESTS: Ensamble (ADN y Feeds) ===");
   
   CEnsembleManager ensamble;
   ensamble.InitializeEnsemble();

   // Test 1: Distribución Módulo 16 de Feeds
   Check("1. Agente 0 asignado al Feed 0", ensamble.GetAgentFeedID(0) == 0);
   Check("2. Agente 15 asignado al Feed 15", ensamble.GetAgentFeedID(15) == 15);
   Check("3. Agente 16 vuelve a asignarse al Feed 0 (Circularidad)", ensamble.GetAgentFeedID(16) == 0);

   // Test 2: Generación de Hecho LISP (String)
   string fact_0 = ensamble.GetAgentFactString(0);
   Check("4. Generación de string LISP no vacía", StringLen(fact_0) > 20);
   
   // Buscamos que incluya la cabecera obligatoria de la plantilla
   int find_header = StringFind(fact_0, "(hiperparametros");
   Check("5. String LISP contiene la plantilla base correcta", find_header >= 0);

   // Test 3: Seguridad de índices fuera de rango
   Check("6. Agente -1 devuelve Feed -1 (Seguridad)", ensamble.GetAgentFeedID(-1) == -1);
   Check("7. Agente 100 devuelve Feed -1 (Límite superior)", ensamble.GetAgentFeedID(100) == -1);
   Check("8. Agente fuera de rango devuelve string vacío", ensamble.GetAgentFactString(101) == "");
  }
//+------------------------------------------------------------------+