//+------------------------------------------------------------------+
//|                                                     Ensamble.mqh |
//|                                  Copyright 2026, Pedro Escudero. |
//+------------------------------------------------------------------+
#property strict

// ========================================================================
// MAPA DE DISTRIBUCIÓN DE FEEDS (16 Combinaciones)
// ------------------------------------------------------------------------
// TIEMPO:  0: M5  |  1: H1   |  2: H4    |  3: D1
// TICKS:   4: 100 |  5: 1500 |  6: 6000  |  7: 24000
// VOLUMEN: 8: 500 |  9: 5000 | 10: 20000 | 11: 80000
// RANGO:  12: 50  | 13: 200  | 14: 500   | 15: 1500
// ========================================================================

// ========================================================================
// ESTRUCTURA: SAgentGenetics
// Almacena la configuración matemática, topológica y de suscripción de datos.
// ========================================================================
struct SAgentGenetics
  {
   int               id;
   int               feed_id; // Identificador de suscripción (0-15)
   
   // --- Dimensión Macro ---
   double            rsi_sobrecompra;
   double            rsi_sobreventa;
   double            atr_expansion;
   double            atr_contraccion;
   double            vwap_desviacion;
   double            alma_pendiente;
   
   // --- Dimensión Micro ---
   double            pinbar_ratio_larga;
   double            pinbar_ratio_corta;
   double            envolvente_ratio;
   double            bos_margen;
   double            insidebar_ratio;
  };

// ========================================================================
// CLASE: CEnsembleManager
// Orquestador genético del enjambre de 100 agentes.
// ========================================================================
class CEnsembleManager
  {
private:
   SAgentGenetics    m_agents[100]; // Matriz estática de 100 agentes
   
   // Generador de números aleatorios con distribución Normal (Box-Muller)
   double            MathRandomNormal(double mean, double std_dev);

public:
                     CEnsembleManager(void);
                    ~CEnsembleManager(void) {}

   void              InitializeEnsemble(void);
   
   // Getters para el Orquestador
   int               GetAgentFeedID(int agent_id) const;
   string            GetAgentFactString(int agent_id) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEnsembleManager::CEnsembleManager(void)
  {
   ZeroMemory(m_agents);
  }

//+------------------------------------------------------------------+
//| Generador Gaussiano basado en la Transformada de Box-Muller      |
//+------------------------------------------------------------------+
double CEnsembleManager::MathRandomNormal(double mean, double std_dev)
  {
   double u1 = (double)MathRand() / 32767.0;
   double u2 = (double)MathRand() / 32767.0;
   
   // Evitar indeterminación matemática con logaritmo de 0
   if(u1 <= 0.0) u1 = 0.0001; 
   
   double z0 = MathSqrt(-2.0 * MathLog(u1)) * MathCos(2.0 * M_PI * u2);
   return (z0 * std_dev) + mean;
  }

//+------------------------------------------------------------------+
//| Inicialización: Configuración de la diversidad del enjambre      |
//+------------------------------------------------------------------+
void CEnsembleManager::InitializeEnsemble(void)
  {
   // Fijamos una semilla para asegurar la replicabilidad de los backtests
   MathSrand(123456); 

   for(int i = 0; i < 100; i++)
     {
      m_agents[i].id = i;
      
      // Asignación uniforme a uno de los 16 Feeds de datos
      m_agents[i].feed_id = i % 16; 
      
      // ===========================================================
      // FASE MACRO: Umbrales Dinámicos
      // ===========================================================
      m_agents[i].rsi_sobrecompra = MathRandomNormal(70.0, 3.5);  
      m_agents[i].rsi_sobreventa  = MathRandomNormal(30.0, 3.5);  
      m_agents[i].atr_expansion   = MathRandomNormal(1.8, 0.25);
      m_agents[i].atr_contraccion = MathRandomNormal(0.7, 0.08);
      m_agents[i].vwap_desviacion = MathRandomNormal(2.0, 0.4);
      m_agents[i].alma_pendiente  = MathRandomNormal(0.001, 0.0002);
      
      // Restricciones lógicas de seguridad (Clamping)
      if(m_agents[i].rsi_sobrecompra > 85.0) m_agents[i].rsi_sobrecompra = 85.0;
      if(m_agents[i].rsi_sobreventa < 15.0)  m_agents[i].rsi_sobreventa = 15.0;

      // ===========================================================
      // FASE MICRO: Exigencia Topológica (Geometría del Precio)
      // ===========================================================
      m_agents[i].pinbar_ratio_larga = MathRandomNormal(2.8, 0.4);
      m_agents[i].pinbar_ratio_corta = MathRandomNormal(0.3, 0.05);
      m_agents[i].envolvente_ratio   = MathRandomNormal(1.15, 0.05);
      m_agents[i].bos_margen         = MathRandomNormal(0.0, 0.0001); 
      m_agents[i].insidebar_ratio    = MathRandomNormal(0.7, 0.08);
      
      // Forzar restricciones geométricas mínimas obligatorias
      if(m_agents[i].pinbar_ratio_larga < 1.5) m_agents[i].pinbar_ratio_larga = 1.5;
      if(m_agents[i].pinbar_ratio_corta < 0.1) m_agents[i].pinbar_ratio_corta = 0.1;
      if(m_agents[i].envolvente_ratio < 1.01)  m_agents[i].envolvente_ratio = 1.01;
     }
  }

//+------------------------------------------------------------------+
//| Getter: Devuelve a qué Feed debe suscribirse el agente           |
//+------------------------------------------------------------------+
int CEnsembleManager::GetAgentFeedID(int agent_id) const
  {
   if(agent_id < 0 || agent_id >= 100) return -1;
   return m_agents[agent_id].feed_id;
  }

//+------------------------------------------------------------------+
//| Construcción del hecho formateado para el motor CLIPS            |
//+------------------------------------------------------------------+
string CEnsembleManager::GetAgentFactString(int agent_id) const
  {
   if(agent_id < 0 || agent_id >= 100) return "";
   
   string fact = StringFormat(
      "(hiperparametros (rsi-sobrecompra %.1f) (rsi-sobreventa %.1f) "
      "(atr-expansion %.2f) (atr-contraccion %.2f) (vwap-desviacion %.2f) (alma-pendiente %.5f) "
      "(pinbar-ratio-larga %.2f) (pinbar-ratio-corta %.2f) (envolvente-ratio %.2f) "
      "(bos-margen %.5f) (insidebar-ratio %.2f))",
      m_agents[agent_id].rsi_sobrecompra,
      m_agents[agent_id].rsi_sobreventa,
      m_agents[agent_id].atr_expansion,
      m_agents[agent_id].atr_contraccion,
      m_agents[agent_id].vwap_desviacion,
      m_agents[agent_id].alma_pendiente,
      m_agents[agent_id].pinbar_ratio_larga,
      m_agents[agent_id].pinbar_ratio_corta,
      m_agents[agent_id].envolvente_ratio,
      m_agents[agent_id].bos_margen,
      m_agents[agent_id].insidebar_ratio
   );
   
   return fact;
  }
//+------------------------------------------------------------------+