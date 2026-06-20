//+------------------------------------------------------------------+
//|                                                Indicadores.mqh   |
//|                                  Copyright 2026, Pedro Escudero. |
//+------------------------------------------------------------------+
#property strict

#include "velas.mqh"

// ========================================================================
// Helper: Extractor de Precio Aplicado
// ========================================================================
double GetAppliedPrice(const SCandle &candle, ENUM_APPLIED_PRICE applied_price)
  {
   switch(applied_price)
     {
      case PRICE_OPEN:   return candle.open;
      case PRICE_HIGH:   return candle.high;
      case PRICE_LOW:    return candle.low;
      case PRICE_CLOSE:  return candle.close;
      case PRICE_MEDIAN: return (candle.high + candle.low) / 2.0;
      case PRICE_TYPICAL:return (candle.high + candle.low + candle.close) / 3.0;
      case PRICE_WEIGHTED:return (candle.high + candle.low + candle.close + candle.close) / 4.0;
      default:           return candle.close;
     }
  }

// ========================================================================
// CLASE BASE: CIndicator
// ========================================================================
class CIndicator
  {
protected:
   CCustomFeed* m_feed;          // Puntero a la tubería de datos
   int                  m_period;        // Período de cálculo
   ENUM_APPLIED_PRICE   m_applied_price; // Precio objetivo
   double               m_current_value; // Último valor calculado
   bool                 m_is_ready;      // ¿Tiene datos suficientes?

public:
                     CIndicator(CCustomFeed* feed, int period, ENUM_APPLIED_PRICE applied_price = PRICE_CLOSE)
                       : m_feed(feed), m_period(period), m_applied_price(applied_price), m_current_value(0.0), m_is_ready(false) {}
                    ~CIndicator(void) {}

   // Método virtual puro que cada indicador deberá implementar
   virtual void      CalculateOnClose() = 0;
   
   double            GetValue() const { return m_current_value; }
   bool              IsReady() const  { return m_is_ready; }
  };

// ========================================================================
// CLASE DERIVADA: CRsiCustom (Ejemplo de implementación)
// ========================================================================
class CRsiCustom : public CIndicator
  {
private:
   double            m_prev_avg_gain;
   double            m_prev_avg_loss;
   long              m_calculated_count; // Cuántas velas hemos procesado

public:
                     CRsiCustom(CCustomFeed* feed, int period, ENUM_APPLIED_PRICE applied_price = PRICE_CLOSE);
   virtual void      CalculateOnClose() override;
  };

// Constructor
CRsiCustom::CRsiCustom(CCustomFeed* feed, int period, ENUM_APPLIED_PRICE applied_price)
  : CIndicator(feed, period, applied_price), m_prev_avg_gain(0.0), m_prev_avg_loss(0.0), m_calculated_count(0)
  {
  }

// Cálculo Incremental (RSI de Wilder)
void CRsiCustom::CalculateOnClose()
  {
   SCandle current_candle, prev_candle;
   
   // CORRECCIÓN: En MQL5 los punteros usan el operador '.' en lugar de '->'
   // Además, inicializamos por seguridad por si la función devuelve false
   ZeroMemory(current_candle);
   ZeroMemory(prev_candle);
   
   if(!m_feed.GetCandle(1, current_candle) || !m_feed.GetCandle(2, prev_candle)) 
      return;

   double current_price = GetAppliedPrice(current_candle, m_applied_price);
   double prev_price = GetAppliedPrice(prev_candle, m_applied_price);
   
   double change = current_price - prev_price;
   double gain = (change > 0) ? change : 0.0;
   double loss = (change < 0) ? -change : 0.0;

   // Primer cálculo (Media Simple de las primeras 'period' velas)
   if(m_calculated_count < m_period)
     {
      m_prev_avg_gain += gain;
      m_prev_avg_loss += loss;
      m_calculated_count++;
      
      if(m_calculated_count == m_period)
        {
         m_prev_avg_gain /= m_period;
         m_prev_avg_loss /= m_period;
         m_is_ready = true;
        }
      return;
     }

   // Cálculo incremental (Wilder Smoothing)
   m_prev_avg_gain = ((m_prev_avg_gain * (m_period - 1)) + gain) / m_period;
   m_prev_avg_loss = ((m_prev_avg_loss * (m_period - 1)) + loss) / m_period;

   if(m_prev_avg_loss == 0.0)
     {
      m_current_value = 100.0;
     }
   else
     {
      double rs = m_prev_avg_gain / m_prev_avg_loss;
      m_current_value = 100.0 - (100.0 / (1.0 + rs));
     }
  }

// ========================================================================
// CLASE DERIVADA: CAtrCustom
// ========================================================================
class CAtrCustom : public CIndicator
  {
public:
                     CAtrCustom(CCustomFeed* feed, int period) : CIndicator(feed, period) {}
   virtual void      CalculateOnClose() override
     {
      SCandle curr, prev;
      if(!m_feed.GetCandle(1, curr) || !m_feed.GetCandle(2, prev)) return;
      double tr = MathMax(curr.high - curr.low, MathMax(MathAbs(curr.high - prev.close), MathAbs(curr.low - prev.close)));
      if(!m_is_ready) { m_current_value = tr; m_is_ready = true; return; }
      m_current_value = (m_current_value * (m_period - 1) + tr) / m_period;
     }
  };

// ========================================================================
// CLASE DERIVADA: CAlmaCustom (Proxy Pendiente EMA)
// ========================================================================
class CAlmaCustom : public CIndicator
  {
private:
   double m_prev_ema;
public:
                     CAlmaCustom(CCustomFeed* feed, int period) : CIndicator(feed, period), m_prev_ema(0) {}
   virtual void      CalculateOnClose() override
     {
      SCandle curr;
      if(!m_feed.GetCandle(1, curr)) return;
      double price = curr.close;
      if(!m_is_ready) { m_prev_ema = price; m_current_value = 0.0; m_is_ready = true; return; }
      double k = 2.0 / (m_period + 1.0);
      double current_ema = (price - m_prev_ema) * k + m_prev_ema;
      m_current_value = current_ema - m_prev_ema; // Pendiente para CLIPS
      m_prev_ema = current_ema;
     }
  };

// ========================================================================
// CLASE DERIVADA: CVwapCustom (Desviación Porcentual)
// ========================================================================
class CVwapCustom : public CIndicator
  {
public:
                     CVwapCustom(CCustomFeed* feed, int period) : CIndicator(feed, period) {}
   virtual void      CalculateOnClose() override
     {
      double sum_pv = 0, sum_v = 0;
      SCandle c;
      for(int i=1; i<=m_period; i++) {
         if(!m_feed.GetCandle(i, c)) break;
         double typ = (c.high + c.low + c.close)/3.0;
         sum_pv += typ * c.volume;
         sum_v += c.volume;
      }
      if(sum_v > 0) {
         double vwap = sum_pv / sum_v;
         m_feed.GetCandle(1, c);
         m_current_value = MathAbs(c.close - vwap) / vwap * 100.0; // Desviación porcentual
         m_is_ready = true;
      }
     }
  };
//+------------------------------------------------------------------+