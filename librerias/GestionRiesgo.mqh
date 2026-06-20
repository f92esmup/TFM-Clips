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
   int               m_thr_level_1;
   int               m_thr_level_2;
   int               m_thr_level_3;
   
   // Riesgo (% del balance)
   double            m_base_risk;       // Ej: 0.5%
   double            m_risk_increment;  // Ej: +0.5% por cada nivel
   
   // Ratios de recompensa (R)
   double            m_ratio_1;         // Ej: 2.0
   double            m_ratio_2;         // Ej: 3.0
   double            m_ratio_3;         // Ej: 4.0

public:
                     CRiskManager(int t1, int t2, int t3, 
                                  double base_risk, double risk_inc, 
                                  double r1, double r2, double r3);
                    ~CRiskManager(void) {}

   void              UpdateAgentVote(int agent_id, string vote_str);
   STradeParams      GetTradeParams(double account_balance);
  };

//+------------------------------------------------------------------+
//| Constructor: Recibe todos los parámetros para optimización       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(int t1, int t2, int t3, double base_risk, double risk_inc, double r1, double r2, double r3)
  {
   m_thr_level_1 = t1;
   m_thr_level_2 = t2;
   m_thr_level_3 = t3;
   m_base_risk = base_risk;
   m_risk_increment = risk_inc;
   m_ratio_1 = r1;
   m_ratio_2 = r2;
   m_ratio_3 = r3;
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
   
   if(net_votes >= m_thr_level_3) target_level = 3;
   else if(net_votes >= m_thr_level_2) target_level = 2;
   else if(net_votes >= m_thr_level_1) target_level = 1;
   
   // Histéresis: Exige caer 10 votos por debajo del umbral para perder el nivel actual
   if(target_level < m_current_level)
     {
      int required_drop = 0;
      if(m_current_level == 3) required_drop = m_thr_level_3 - 10;
      else if(m_current_level == 2) required_drop = m_thr_level_2 - 10;
      else if(m_current_level == 1) required_drop = m_thr_level_1 - 10;
      
      if(net_votes >= required_drop)
         target_level = m_current_level; // Mantener nivel por inercia
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