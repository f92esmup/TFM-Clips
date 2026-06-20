;; ========================================================================
;; MÓDULO MACRO: EVALUACIÓN DEL RÉGIMEN DE MERCADO
;; ========================================================================
;; FUNCIÓN:
;; Este módulo contiene las reglas lógicas que transforman los datos numéricos
;; crudos de los indicadores en estados de mercado discretos. 
;; Lee el "ADN" del agente (hiperparametros) para determinar sus propios 
;; umbrales de activación, garantizando la heterogeneidad del ensamble.
;;
;; DEPENDENCIAS:
;; - Requiere que el módulo MAIN (00_templates.clp) esté cargado.
;; - MQL5 debe inyectar los hechos 'hiperparametros' e 'indicador' antes 
;;   de enfocar este módulo.
;; ========================================================================
(defmodule MACRO (import MAIN ?ALL) (export ?ALL))

;; ========================================================================
;; 1. DIMENSIÓN DEL MOMENTO (RSI)
;; ------------------------------------------------------------------------
;; Evalúa la tensión del mercado cruzando el valor del RSI con la 
;; sensibilidad a la sobrecompra/sobreventa específica de este agente.
;; ========================================================================
(defrule macro-momento-sobrecomprado
   "Detecta si el RSI supera el umbral dinámico de sobrecompra del agente"
   (hiperparametros (rsi-sobrecompra ?umbral-sc))
   (indicador (nombre RSI) (valor ?v))
   (test (> ?v ?umbral-sc))
   =>
   (assert (macroestado (dimension momento) (condicion sobrecomprado)))
)

(defrule macro-momento-sobrevendido
   "Detecta si el RSI cae bajo el umbral dinámico de sobreventa del agente"
   (hiperparametros (rsi-sobreventa ?umbral-sv))
   (indicador (nombre RSI) (valor ?v))
   (test (< ?v ?umbral-sv))
   =>
   (assert (macroestado (dimension momento) (condicion sobrevendido)))
)

;; ========================================================================
;; 2. DIMENSIÓN DIRECCIONAL (ALMA)
;; ------------------------------------------------------------------------
;; Filtra el ruido lateral. Exige que la pendiente de la media móvil 
;; supere la exigencia mínima del agente para considerarlo tendencia.
;; ========================================================================
(defrule macro-tendencia-alcista
   "Verifica si la pendiente positiva supera la exigencia del agente"
   (hiperparametros (alma-pendiente ?pendiente-minima))
   (indicador (nombre ALMA) (valor ?v))
   (test (> ?v ?pendiente-minima))
   =>
   (assert (macroestado (dimension direccional) (condicion alcista)))
)

(defrule macro-tendencia-bajista
   "Verifica si la pendiente negativa supera la exigencia del agente"
   (hiperparametros (alma-pendiente ?pendiente-minima))
   (indicador (nombre ALMA) (valor ?v))
   ;; Invertimos el signo del hiperparámetro para evaluar caídas
   (test (< ?v (* -1.0 ?pendiente-minima))) 
   =>
   (assert (macroestado (dimension direccional) (condicion bajista)))
)

;; ========================================================================
;; 3. DIMENSIÓN DE LA VOLATILIDAD (ATR)
;; ------------------------------------------------------------------------
;; Mide la energía del mercado. Compara el ATR actual contra su media
;; utilizando los multiplicadores de expansión y contracción del agente.
;; ========================================================================
(defrule macro-volatilidad-alta
   "El ATR supera el multiplicador de expansión configurado"
   (hiperparametros (atr-expansion ?umbral-exp))
   (indicador (nombre ATR) (valor ?v))
   (test (> ?v ?umbral-exp))
   =>
   (assert (macroestado (dimension volatilidad) (condicion alta)))
)

(defrule macro-volatilidad-baja
   "El ATR cae por debajo del límite de contracción configurado"
   (hiperparametros (atr-contraccion ?umbral-cont))
   (indicador (nombre ATR) (valor ?v))
   (test (< ?v ?umbral-cont))
   =>
   (assert (macroestado (dimension volatilidad) (condicion baja)))
)

;; ========================================================================
;; 4. DIMENSIÓN DE LIQUIDEZ (VWAP)
;; ------------------------------------------------------------------------
;; Determina si el precio se encuentra en estado de desequilibrio respecto 
;; al volumen transaccional medio.
;; ========================================================================
(defrule macro-liquidez-alejada
   "El precio se aleja porcentualmente más allá del límite del agente"
   (hiperparametros (vwap-desviacion ?umbral-desv))
   (indicador (nombre VWAP) (valor ?v))
   (test (> ?v ?umbral-desv))
   =>
   (assert (macroestado (dimension liquidez) (condicion alejada)))
)