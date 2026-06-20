;; ========================================================================
;; MÓDULO DECISION: GENERACIÓN DEL VOTO DEL AGENTE
;; ========================================================================
;; FUNCIÓN:
;; Cruza las dimensiones del Régimen de Mercado (Macro) con la topología 
;; de la Acción del Precio (Micro) para tomar una decisión operativa.
;; 
;; DEPENDENCIAS:
;; - Requiere que los módulos MACRO y MICRO ya hayan sido ejecutados y 
;;   hayan asertado sus respectivos hechos.
;; - MQL5 capturará el hecho 'voto' al finalizar la ejecución de este módulo
;;   para calcular el consenso global de los 100 agentes.
;; ========================================================================
(defmodule DECISION (import MAIN ?ALL) (export ?ALL))


;; ========================================================================
;; 1. ESCENARIOS DE COMPRA (ENTRADA / AUMENTO DE EXPOSICIÓN)
;; ========================================================================

(defrule decision-comprar-continuacion-alcista
   "Condición: Tendencia alcista, con expansión de volatilidad (energía) 
    y un patrón de acción del precio que confirma la dirección alcista."
   (macroestado (dimension direccional) (condicion alcista))
   (macroestado (dimension volatilidad) (condicion alta))
   ;; El operador 'or' permite agrupar múltiples patrones válidos
   (or (microestado (patron pin-bar) (direccion alcista))
       (microestado (patron envolvente) (direccion alcista)))
   =>
   (assert (voto (accion comprar)))
)


(defrule decision-comprar-ruptura-estructural
   "Condicion: Tendencia alcista fuerte que acaba de generar una ruptura estructural (BoS) alcista."
   (macroestado (dimension direccional) (condicion alcista))
   (microestado (patron bos) (direccion alcista))
   =>
   (assert (voto (accion comprar)))
)

(defrule decision-comprar-rebote-sobrevendido
   "Condicion: El mercado esta sobrevendido y en zona de liquidez, y un patron alcista sugiere el rebote."
   (macroestado (dimension momento) (condicion sobrevendido))
   (macroestado (dimension liquidez) (condicion alejada))
   (or (microestado (patron pin-bar) (direccion alcista))
       (microestado (patron envolvente) (direccion alcista)))
   =>
   (assert (voto (accion comprar)))
)
;; ========================================================================
;; 2. ESCENARIOS DE REDUCCIÓN (TOMA DE BENEFICIOS / PROTECCIÓN)
;; ========================================================================

(defrule decision-reducir-agotamiento-alcista
   "Condición: El mercado presenta tensión alta (sobrecompra) y el precio 
    forma un patrón de giro o ruptura estructural bajista."
   (macroestado (dimension momento) (condicion sobrecomprado))
   (or (microestado (patron pin-bar) (direccion bajista))
       (microestado (patron bos) (direccion bajista)))
   =>
   (assert (voto (accion reducir)))
)

(defrule decision-reducir-falta-liquidez
   "Condición: El precio se ha alejado demasiado del VWAP (desequilibrio) 
    y aparece una compresión de volatilidad (incertidumbre)."
   (macroestado (dimension liquidez) (condicion alejada))
   (microestado (patron inside-bar))
   =>
   (assert (voto (accion reducir)))
)


(defrule decision-comprar-acumulacion
   "Condicion: El mercado consolida con baja volatilidad (Inside Bar) pero la tendencia de fondo es alcista. Indica acumulacion antes de explotar."
   (macroestado (dimension direccional) (condicion alcista))
   (macroestado (dimension volatilidad) (condicion baja))
   (microestado (patron inside-bar))
   =>
   (assert (voto (accion comprar)))
)

(defrule decision-comprar-fuerza-bruta
   "Condicion: Todo a favor. Tendencia alcista, alta volatilidad y el RSI NO esta sobrecomprado."
   (macroestado (dimension direccional) (condicion alcista))
   (macroestado (dimension volatilidad) (condicion alta))
   (not (macroestado (dimension momento) (condicion sobrecomprado)))
   (or (microestado (patron bos) (direccion alcista))
       (microestado (patron envolvente) (direccion alcista)))
   =>
   (assert (voto (accion comprar)))
)

(defrule decision-reducir-cambio-tendencia
   "Condicion: El ALMA ha girado a la baja de forma agresiva. Regla de proteccion pura."
   (macroestado (dimension direccional) (condicion bajista))
   =>
   (assert (voto (accion reducir)))
)

(defrule decision-reducir-freno-volatilidad
   "Condicion: El mercado se ha quedado sin energia (ATR bajo) estando sobrecomprado."
   (macroestado (dimension volatilidad) (condicion baja))
   (macroestado (dimension momento) (condicion sobrecomprado))
   =>
   (assert (voto (accion reducir)))
)
;; ========================================================================
;; 3. ESCENARIOS DE ESPERA (INACCIÓN)
;; ========================================================================

(defrule decision-esperar-por-ruido
   "Si el módulo MICRO no encontró estructura y asertó 'ruido', el agente 
    no opera, sin importar lo que digan los indicadores macro."
   (microestado (patron ruido))
   =>
   (assert (voto (accion esperar)))
)


;; ========================================================================
;; 4. REGLA POR DEFECTO (SAFETY NET / FALLBACK)
;; ========================================================================

(defrule decision-esperar-por-defecto
   "Regla de control: Si el mercado genera una combinación de macro y micro 
    que no está contemplada en ninguna regla anterior de compra o reducción, 
    el agente emite el voto de 'esperar' para evitar errores de ejecución."
   (declare (salience -10)) ; Baja prioridad: se ejecuta en último lugar
   (not (voto))             ; Verifica que no se haya emitido un voto antes
   =>
   (assert (voto (accion esperar)))
)

;; ========================================================================
;; 5. FUNCIONES DE EXTRACCIÓN PARA MQL5
;; ========================================================================

(deffunction obtener-voto ()
   "Extrae el valor del slot 'accion' del hecho 'voto'. Devuelve 'esperar' si no lo encuentra."
   (do-for-fact ((?v voto)) TRUE
      (return ?v:accion)
   )
   (return esperar)
)
