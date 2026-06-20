//+------------------------------------------------------------------+
//|                                                   TaskQueue.mqh  |
//|                                  Copyright 2026, Pedro Escudero. |
//+------------------------------------------------------------------+
#property strict

// ========================================================================
// CLASE: CTaskQueue
// FUNCIÓN: Implementa una cola FIFO (First In, First Out) de tamaño fijo 
// y circular. Diseñada para encolar agentes con complejidad O(1) y latencia 0.
// ========================================================================
class CTaskQueue
  {
private:
   int               m_queue[100]; // Array estático: el máximo teórico de agentes
   int               m_head;       // Puntero de lectura (Pop)
   int               m_tail;       // Puntero de escritura (Push)
   int               m_count;      // Elementos actuales en la cola

public:
                     CTaskQueue(void);
                    ~CTaskQueue(void) {}

   // Métodos principales
   bool              Push(int agent_id);
   int               Pop(void);
   
   // Métodos de estado
   int               Count(void) const { return m_count; }
   bool              IsEmpty(void) const { return (m_count == 0); }
   bool              IsFull(void) const { return (m_count == 100); }
   void              Clear(void);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTaskQueue::CTaskQueue(void) : m_head(0), m_tail(0), m_count(0)
  {
   ArrayInitialize(m_queue, -1);
  }

//+------------------------------------------------------------------+
//| Push: Inserta el ID de un agente en la cola                      |
//+------------------------------------------------------------------+
bool CTaskQueue::Push(int agent_id)
  {
   if(IsFull()) 
     {
      Print("Error Crítico: TaskQueue llena. Imposible encolar agente ", agent_id);
      return false;
     }
     
   m_queue[m_tail] = agent_id;
   m_tail = (m_tail + 1) % 100; // Lógica circular: si llega a 100, vuelve al índice 0
   m_count++;
   
   return true;
  }

//+------------------------------------------------------------------+
//| Pop: Extrae y devuelve el próximo ID de la cola                  |
//+------------------------------------------------------------------+
int CTaskQueue::Pop(void)
  {
   if(IsEmpty()) return -1; // Devuelve -1 si la cola está vacía
   
   int agent_id = m_queue[m_head];
   m_head = (m_head + 1) % 100; // Movimiento circular del puntero
   m_count--;
   
   return agent_id;
  }

//+------------------------------------------------------------------+
//| Clear: Vacía la cola instantáneamente                            |
//+------------------------------------------------------------------+
void CTaskQueue::Clear(void)
  {
   m_head = 0;
   m_tail = 0;
   m_count = 0;
  }
//+------------------------------------------------------------------+