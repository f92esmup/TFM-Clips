//+------------------------------------------------------------------+
//|                                                GestionRiesgo.mqh |
//|                                  Copyright 2026, Pedro Escudero. |
//+------------------------------------------------------------------+
#property strict

// ========================================================================
// ESTRUCTURA: Devolución de parámetros de ejecución
// ========================================================================
struct STradeParams
  {
   double            risk_amount;       // Dinero físico a arriesgar ($ o €)
   double            take_profit_ratio; // Multiplicador para el TP (R)
  };

enum ENUM_AGENT_VOTE { VOTE_BUY = 1, VOTE_REDUCE = -1, VOTE_WAIT = 0 };

// ========================================================================
// CLASE: CRiskManager (Modelo Democrático por Niveles)
// ========================================================================
class CRiskManager
  {
private:
   ENUM_AGENT_VOTE   m_votes[100];      // Memoria de los 100 agentes
   int               m_current_level;   // Nivel de riesgo actualmente activo
   
   // --- Hiperparámetros Optimizables ---
   // Umbrales de votos (0 a 100)
   int               m_thr_level1;
   int               m_thr_level2;
   int               m_thr_level3;
   int               m_hysteresis;
   
   // Riesgo (% del balance)
   double            m_base_risk;       // Ej: 0.5%
   double            m_risk_increment;  // Ej: +0.5% por cada nivel
   
   // Ratios de recompensa (R)
   double            m_ratio_1;         // Ej: 2.0
   double            m_ratio_2;         // Ej: 3.0
   double            m_ratio_3;         // Ej: 4.0

public:
                     CRiskManager(int thr_base, int thr_step, int hysteresis,
                                  double risk_base, double risk_inc,
                                  double ratio1, double ratio2, double ratio3);
                    ~CRiskManager(void) {}

   void              UpdateAgentVote(int agent_id, string vote_str);
   STradeParams      GetTradeParams(double account_balance);
   
   int               GetNetVotes() const;
   void              GetVoteCounts(int &out_buy, int &out_reduce, int &out_wait) const;
   int               GetCurrentLevel() const { return m_current_level; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(int thr_base, int thr_step, int hysteresis,
                           double risk_base, double risk_inc,
                           double ratio1, double ratio2, double ratio3)
  {
   m_thr_level1 = thr_base;
   m_thr_level2 = thr_base + thr_step;
   m_thr_level3 = thr_base + (thr_step * 2);
   m_hysteresis = hysteresis;
   m_base_risk = risk_base;
   m_risk_increment = risk_inc;
   m_ratio_1 = ratio1;
   m_ratio_2 = ratio2;
   m_ratio_3 = ratio3;
   m_current_level = 0;
   
   for(int i = 0; i < 100; i++) 
      m_votes[i] = VOTE_WAIT;
  }

//+------------------------------------------------------------------+
//| Actualiza el voto en memoria (1 Agente = 1 Voto)                 |
//+------------------------------------------------------------------+
void CRiskManager::UpdateAgentVote(int agent_id, string vote_str)
  {
   if(agent_id < 0 || agent_id >= 100) return;
   
   if(vote_str == "comprar")      m_votes[agent_id] = VOTE_BUY;
   else if(vote_str == "reducir") m_votes[agent_id] = VOTE_REDUCE;
   else                           m_votes[agent_id] = VOTE_WAIT;
  }

//+------------------------------------------------------------------+
//| Extrae el voto neto para propósitos de visualización (HUD)       |
//+------------------------------------------------------------------+
int CRiskManager::GetNetVotes() const
  {
   int buy_votes = 0;
   int reduce_votes = 0;
   for(int i = 0; i < 100; i++) 
     {
      if(m_votes[i] == VOTE_BUY) buy_votes++;
      else if(m_votes[i] == VOTE_REDUCE) reduce_votes++;
     }
   return buy_votes - reduce_votes;
  }

//+------------------------------------------------------------------+
//| Desglosa los votos totales por categoría para el HUD             |
//+------------------------------------------------------------------+
void CRiskManager::GetVoteCounts(int &out_buy, int &out_reduce, int &out_wait) const
  {
   out_buy = 0;
   out_reduce = 0;
   out_wait = 0;
   for(int i = 0; i < 100; i++) 
     {
      if(m_votes[i] == VOTE_BUY) out_buy++;
      else if(m_votes[i] == VOTE_REDUCE) out_reduce++;
      else out_wait++;
     }
  }

//+------------------------------------------------------------------+
//| Motor de Decisión: Evalúa el conteo y asigna riesgo/ratio        |
//+------------------------------------------------------------------+
STradeParams CRiskManager::GetTradeParams(double balance)
  {
   STradeParams params = {0.0, 0.0};
   
   // 1. Conteo Democrático
   int buy_votes = 0;
   int reduce_votes = 0;
   
   for(int i = 0; i < 100; i++) 
     {
      if(m_votes[i] == VOTE_BUY) buy_votes++;
      else if(m_votes[i] == VOTE_REDUCE) reduce_votes++;
     }
   
   int net_votes = buy_votes - reduce_votes;
   
   // 2. Asignación por Niveles de Certeza con Histéresis
   int target_level = 0;
   
   if(net_votes >= m_thr_level3) target_level = 3;
   else if(net_votes >= m_thr_level2) target_level = 2;
   else if(net_votes >= m_thr_level1) target_level = 1;
   else
     {
      // Histéresis controlada por el usuario para evitar overtrading
      if(m_current_level == 3 && net_votes < (m_thr_level3 - m_hysteresis)) m_current_level = 2;
      if(m_current_level == 2 && net_votes < (m_thr_level2 - m_hysteresis)) m_current_level = 1;
      if(m_current_level == 1 && net_votes < (m_thr_level1 - m_hysteresis)) m_current_level = 0;
      target_level = m_current_level;
     }
     
   m_current_level = target_level;
   
   if(m_current_level == 3)      
     { 
      // Nivel Máximo: Riesgo Base + (2 * Incremento)
      params.risk_amount = balance * ((m_base_risk + (2.0 * m_risk_increment)) / 100.0); 
      params.take_profit_ratio = m_ratio_3; 
     }
   else if(m_current_level == 2) 
     { 
      // Nivel Medio: Riesgo Base + Incremento
      params.risk_amount = balance * ((m_base_risk + m_risk_increment) / 100.0); 
      params.take_profit_ratio = m_ratio_2; 
     }
   else if(m_current_level == 1) 
     { 
      // Nivel Base: Riesgo Base
      params.risk_amount = balance * (m_base_risk / 100.0); 
      params.take_profit_ratio = m_ratio_1; 
     }
   
   return params; // Si net_votes no llega al Nivel 1, devuelve {0.0, 0.0} (No operar)
  }
//+------------------------------------------------------------------+