;; ========================================================================
;; MÓDULO MAIN: ESTRUCTURAS BASE
;; ========================================================================
;; Se define el módulo MAIN y se exportan todas las plantillas para que 
;; puedan ser leídas y utilizadas por los módulos posteriores.
;; ========================================================================
(defmodule MAIN (export ?ALL))

;; ========================================================================
;; TEMPLATE: HIPERPARÁMETROS (NUEVO)
;; ------------------------------------------------------------------------
;; FUNCIÓN: 
;; Recibe los umbrales de decisión generados aleatoriamente por MQL5.
;; Actúa como el "ADN" del agente, dotándolo de su propia tolerancia al 
;; riesgo, sensibilidad a los indicadores y rigidez geométrica.
;;
;; DEPENDENCIAS: 
;; - MQL5: Debe inyectar un único hecho de esta plantilla al inicio de 
;;   cada iteración, antes de inyectar los indicadores y las velas.
;; - Módulos MACRO y MICRO: Leen estas variables para condicionar sus reglas lógicas.
;; ========================================================================
(deftemplate hiperparametros
   "Configuración genética del agente para la iteración actual"
   
   ;; --- Fase Macro (Sensibilidad Lógica) ---
   (slot rsi-sobrecompra (type FLOAT))
   (slot rsi-sobreventa (type FLOAT))
   (slot atr-expansion (type FLOAT))
   (slot atr-contraccion (type FLOAT))
   (slot vwap-desviacion (type FLOAT))
   (slot alma-pendiente (type FLOAT))
   
   ;; --- Fase Micro (Exigencia Topológica) ---
   (slot pinbar-ratio-larga (type FLOAT))
   (slot pinbar-ratio-corta (type FLOAT))
   (slot envolvente-ratio (type FLOAT))
   (slot bos-margen (type FLOAT))
   (slot insidebar-ratio (type FLOAT))
)

;; ========================================================================
;; TEMPLATE: INDICADOR (Fase MACRO)
;; ------------------------------------------------------------------------
;; FUNCIÓN:
;; Almacena el valor numérico inyectado desde MQL5.
;; ========================================================================
(deftemplate indicador
   (slot nombre (type SYMBOL) (allowed-symbols ALMA RSI ATR VWAP)) 
   (slot valor (type FLOAT))
)

;; ========================================================================
;; TEMPLATE: MACROESTADO (Resultado Fase MACRO)
;; ------------------------------------------------------------------------
;; FUNCIÓN:
;; Clasificación lógica del mercado según la teoría de regímenes.
;; ========================================================================
(deftemplate macroestado
   (slot dimension (type SYMBOL) (allowed-symbols direccional momento volatilidad liquidez))
   (slot condicion (type SYMBOL)) 
)

;; ========================================================================
;; TEMPLATE: VELA (Fase MICRO)
;; ------------------------------------------------------------------------
;; FUNCIÓN: 
;; Representa una vela individual inyectada en crudo por MQL5.
;;
;; DEPENDENCIAS: 
;; - MQL5: Debe inyectar un hecho por cada vela de la ventana temporal.
;;   Ejemplo: (assert (vela (id 0) (open 1.1) (high 1.2) (low 1.0) (close 1.15)))
;;   El id 0 siempre será la vela actual recién cerrada.
;; ========================================================================
(deftemplate vela
   "Datos puros de precios para evaluación temporal en CLIPS"
   (slot id (type INTEGER)) ; Índice temporal: 0 = actual, 1 = anterior, etc.
   (slot open (type FLOAT))
   (slot high (type FLOAT))
   (slot low (type FLOAT))
   (slot close (type FLOAT))
)

;; ========================================================================
;; TEMPLATE: MICROESTADO (Resultado Fase MICRO)
;; ------------------------------------------------------------------------
;; FUNCIÓN:
;; Estructura topológica deducida por las matemáticas internas de CLIPS.
;; ========================================================================
(deftemplate microestado
   (slot patron (type SYMBOL) (allowed-symbols pin-bar bos envolvente inside-bar ruido))
   (slot direccion (type SYMBOL) (allowed-symbols alcista bajista neutro))
)

;; ========================================================================
;; TEMPLATE: VOTO (Resultado Fase DECISION)
;; ------------------------------------------------------------------------
;; FUNCIÓN:
;; Decisión final del agente para el ensamble en MQL5.
;; ========================================================================
(deftemplate voto
   (slot accion (type SYMBOL) (allowed-symbols comprar reducir esperar))
)