//+------------------------------------------------------------------+
//|                                                        velas.mqh |
//|                                  Copyright 2026, Pedro Escudero. |
//+------------------------------------------------------------------+
#property strict

// ========================================================================
// ESTRUCTURA: SCandle
// Representa una vela agnóstica (puede ser temporal, de ticks o volumen)
// ========================================================================
struct SCandle
  {
   double            open;
   double            high;
   double            low;
   double            close;
   long              tick_count; // Contador interno para saber cuándo cerrar
   double            volume;     // Volumen acumulado
  };

// ========================================================================
// CLASE: CCustomFeed
// Generador de velas personalizadas basado en un Buffer Circular O(1).
// ========================================================================
class CCustomFeed
  {
private:
   SCandle           m_buffer[];      // El array circular estático
   int               m_capacity;      // Tamaño máximo de la ventana temporal
   int               m_head;          // Índice de la vela actual en formación
   long              m_ticks_limit;   // Cuántos ticks forman una vela
   
   void              ResetCandle(int index, double price);

public:
                     CCustomFeed(int history_size, long ticks_per_candle);
                    ~CCustomFeed(void) {}

   bool              UpdateTick(double price, double tick_vol);
   bool              GetCandle(int clips_id, SCandle &out_candle) const;
   
   // NUEVO: Traductor de datos para el motor experto
   string            GetClipsFacts(int window_size) const;
   
   int               GetAvailableBars() const;
  };

CCustomFeed::CCustomFeed(int history_size, long ticks_per_candle)
  {
   m_capacity = history_size;
   ArrayResize(m_buffer, m_capacity);
   m_ticks_limit = ticks_per_candle;
   m_head = 0;
   
   for(int i = 0; i < m_capacity; i++) ZeroMemory(m_buffer[i]);
  }

void CCustomFeed::ResetCandle(int index, double price)
  {
   m_buffer[index].open = price;
   m_buffer[index].high = price;
   m_buffer[index].low = price;
   m_buffer[index].close = price;
   m_buffer[index].tick_count = 0;
   m_buffer[index].volume = 0;
  }

bool CCustomFeed::UpdateTick(double price, double tick_vol)
  {
   bool is_new_candle = false;

   if(m_buffer[m_head].tick_count == 0 && m_buffer[m_head].open == 0.0) ResetCandle(m_head, price);

   m_buffer[m_head].close = price;
   if(price > m_buffer[m_head].high) m_buffer[m_head].high = price;
   if(price < m_buffer[m_head].low)  m_buffer[m_head].low = price;
   
   m_buffer[m_head].tick_count++;
   m_buffer[m_head].volume += tick_vol;

   if(m_buffer[m_head].tick_count >= m_ticks_limit)
     {
      is_new_candle = true;
      m_head = (m_head + 1) % m_capacity;
      ResetCandle(m_head, price);
     }
   return is_new_candle;
  }

bool CCustomFeed::GetCandle(int clips_id, SCandle &out_candle) const
  {
   if(clips_id < 0 || clips_id >= m_capacity) return false;
   int real_index = (m_head - clips_id + m_capacity) % m_capacity;
   out_candle = m_buffer[real_index];
   return true;
  }

// --- LA NUEVA FUNCIÓN PARA CLIPS ---
string CCustomFeed::GetClipsFacts(int window_size) const
  {
   string facts = "";
   SCandle temp_candle;
   int limit = (window_size > m_capacity) ? m_capacity : window_size;

   for(int i = 1; i <= limit; i++)
     {
      if(GetCandle(i, temp_candle) && temp_candle.open != 0.0)
        {
         facts += StringFormat("(vela (id %d) (open %.5f) (high %.5f) (low %.5f) (close %.5f)) ",
                               i - 1, temp_candle.open, temp_candle.high, temp_candle.low, temp_candle.close);
        }
     }
   return facts;
  }

// --- CONTADOR DE VELAS DISPONIBLES ---
int CCustomFeed::GetAvailableBars() const
  {
   int count = 0;
   for(int i = 0; i < m_capacity; i++)
     {
      if(m_buffer[i].open != 0.0 || m_buffer[i].tick_count > 0) count++;
     }
   return count;
  }
//+------------------------------------------------------------------+