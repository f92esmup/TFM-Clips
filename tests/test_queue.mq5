//+------------------------------------------------------------------+
//|                                                   test_queue.mq5 |
//+------------------------------------------------------------------+
#property strict
#include <tfm\TaskQueue.mqh>

void Check(string name, bool condition)
  {
   PrintFormat("TEST: %s | [%s]", name, condition ? "PASS" : "FAIL");
  }

void OnStart()
  {
   Print("=== INICIANDO TESTS: TaskQueue ===");
   CTaskQueue queue;

   // Test 1: Estado inicial
   Check("1. Cola recién creada está vacía", queue.IsEmpty() == true && queue.Count() == 0);

   // Test 2: Inserción básica
   queue.Push(42);
   Check("2. Push simple incrementa Count a 1", queue.Count() == 1 && queue.IsEmpty() == false);

   // Test 3: Extracción (Pop)
   int id = queue.Pop();
   Check("3. Pop devuelve el ID correcto y vacía la cola", id == 42 && queue.IsEmpty() == true);

   // Test 4: Llenado hasta el límite (100 agentes)
   for(int i = 0; i < 100; i++) queue.Push(i);
   Check("4. Llenado exacto hasta capacidad máxima (100)", queue.IsFull() == true && queue.Count() == 100);

   // Test 5: Desbordamiento de buffer (Seguridad)
   bool overflow = queue.Push(101);
   Check("5. Push extra rechaza la inserción de forma segura", overflow == false && queue.Count() == 100);

   // Test 6: Circularidad de punteros (Head/Tail wrap-around)
   queue.Pop(); queue.Pop(); queue.Pop(); // Sacamos 3
   queue.Push(200); queue.Push(201); queue.Push(202); // Metemos 3 nuevos
   Check("6. Comportamiento circular sin redimensionar array", queue.IsFull() == true && queue.Count() == 100);

   // Test 7: Vaciado manual
   queue.Clear();
   Check("7. Clear resetea todos los punteros a 0", queue.IsEmpty() == true && queue.Count() == 0);
  }
//+------------------------------------------------------------------+