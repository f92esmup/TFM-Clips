;; ========================================================================
;; MÓDULO MICRO: EVALUACIÓN TOPOLÓGICA (PRICE ACTION) LISP
;; ========================================================================
;; FUNCIÓN:
;; Este módulo asume el control total de las matemáticas. Evalúa las velas
;; en crudo (OHLC), extrae proporciones restando precios y busca patrones
;; cruzando la vela actual (id 0) con las históricas (id > 0).
;;
;; HETEROGENEIDAD:
;; Utiliza las exigencias geométricas definidas en el template de 
;; 'hiperparametros' inyectado por MQL5. Un agente puede ser muy estricto
;; pidiendo mechas gigantescas, mientras que otro puede ser más laxo.
;; ========================================================================
(defmodule MICRO (import MAIN ?ALL) (export ?ALL))

;; ========================================================================
;; 1. AGOTAMIENTO / CAZA DE LIQUIDEZ (PIN BAR)
;; ------------------------------------------------------------------------
;; Verifica si el rechazo del precio (la mecha a favor) y la mecha en
;; contra cumplen con los multiplicadores exigidos por este agente.
;; ========================================================================

(defrule micro-pin-bar-alcista
   "Vela alcista con rechazo inferior que cumple el ratio del agente"
   (hiperparametros (pinbar-ratio-larga ?ratio-l) (pinbar-ratio-corta ?ratio-c))
   (vela (id 0) (open ?o0) (close ?c0) (high ?h0) (low ?l0))
   
   (test (>= ?c0 ?o0)) ; Filtro: la vela debe ser alcista o doji
   
   ;; Mecha inf >= (Cuerpo * Ratio Largo)
   (test (>= (- ?o0 ?l0) (* ?ratio-l (- ?c0 ?o0)))) 
   
   ;; Mecha sup <= (Cuerpo * Ratio Corto)
   (test (<= (- ?h0 ?c0) (* ?ratio-c (- ?c0 ?o0)))) 
   =>
   (assert (microestado (patron pin-bar) (direccion alcista)))
)

(defrule micro-pin-bar-bajista
   "Vela bajista con rechazo superior que cumple el ratio del agente"
   (hiperparametros (pinbar-ratio-larga ?ratio-l) (pinbar-ratio-corta ?ratio-c))
   (vela (id 0) (open ?o0) (close ?c0) (high ?h0) (low ?l0))
   
   (test (< ?c0 ?o0)) ; Filtro: la vela debe ser bajista
   
   ;; Mecha sup >= (Cuerpo * Ratio Largo)
   (test (>= (- ?h0 ?o0) (* ?ratio-l (- ?o0 ?c0)))) 
   
   ;; Mecha inf <= (Cuerpo * Ratio Corto)
   (test (<= (- ?c0 ?l0) (* ?ratio-c (- ?o0 ?c0)))) 
   =>
   (assert (microestado (patron pin-bar) (direccion bajista)))
)

;; ========================================================================
;; 2. ABSORCIÓN INSTITUCIONAL (VELA ENVOLVENTE)
;; ------------------------------------------------------------------------
;; No basta con que el precio cubra la vela anterior; el cuerpo de la vela 
;; actual debe superar al previo en el porcentaje exigido por el agente.
;; ========================================================================

(defrule micro-envolvente-alcista
   "El cuerpo alcista actual envuelve al bajista previo con la fuerza exigida"
   (hiperparametros (envolvente-ratio ?ratio-env))
   (vela (id 0) (open ?o0) (close ?c0))
   (vela (id 1) (open ?o1) (close ?c1))
   
   (test (> ?c0 ?o0))  ; Vela 0 es alcista
   (test (< ?c1 ?o1))  ; Vela 1 es bajista
   (test (<= ?o0 ?c1)) ; Apertura 0 cubre cierre 1
   (test (>= ?c0 ?o1)) ; Cierre 0 cubre apertura 1
   
   ;; Cuerpo 0 > (Cuerpo 1 * Ratio de Envoltura)
   (test (> (- ?c0 ?o0) (* ?ratio-env (- ?o1 ?c1)))) 
   =>
   (assert (microestado (patron envolvente) (direccion alcista)))
)

(defrule micro-envolvente-bajista
   "El cuerpo bajista actual envuelve al alcista previo con la fuerza exigida"
   (hiperparametros (envolvente-ratio ?ratio-env))
   (vela (id 0) (open ?o0) (close ?c0))
   (vela (id 1) (open ?o1) (close ?c1))
   
   (test (< ?c0 ?o0))  
   (test (> ?c1 ?o1))  
   (test (>= ?o0 ?c1)) 
   (test (<= ?c0 ?o1)) 
   
   ;; Cuerpo 0 > (Cuerpo 1 * Ratio de Envoltura)
   (test (> (- ?o0 ?c0) (* ?ratio-env (- ?c1 ?o1))))
   =>
   (assert (microestado (patron envolvente) (direccion bajista)))
)

;; ========================================================================
;; 3. COMPRESIÓN DE VOLATILIDAD (INSIDE BARS)
;; ------------------------------------------------------------------------
;; Exige que la vela actual esté contenida dentro del rango de la anterior,
;; limitando su tamaño total según la exigencia geométrica del agente.
;; ========================================================================

(defrule micro-inside-bar
   "El tamaño total de la vela 0 es menor al porcentaje permitido de la vela 1"
   (hiperparametros (insidebar-ratio ?ratio-max))
   (vela (id 0) (open ?o0) (close ?c0) (high ?h0) (low ?l0))
   (vela (id 1) (high ?h1) (low ?l1))
   
   (test (< ?h0 ?h1)) ; Máximo decreciente
   (test (> ?l0 ?l1)) ; Mínimo creciente
   
   ;; Rango 0 <= (Rango 1 * Ratio Máximo Permitido)
   (test (<= (- ?h0 ?l0) (* ?ratio-max (- ?h1 ?l1))))
   =>
   (assert (microestado (patron inside-bar) (direccion neutro)))
)

;; ========================================================================
;; 4. RUPTURA ESTRUCTURAL (BoS)
;; ------------------------------------------------------------------------
;; Evalúa el salto de nivel histórico filtrando falsas rupturas utilizando
;; el margen (en puntos o precio) configurado para este agente.
;; ========================================================================

(defrule micro-bos-alcista
   "El cierre actual supera a TODOS los máximos históricos más el margen"
   (hiperparametros (bos-margen ?margen))
   (vela (id 0) (close ?c0))
   (vela (id ?idx&~0)) ; Condición: Existe histórico
   
   ;; Busca la inexistencia de una vela cuyo High sea mayor al Cierre 0 menos el margen
   (not (vela (id ?id-hist&~0) (high ?h&:(>= ?h (- ?c0 ?margen)))))
   =>
   (assert (microestado (patron bos) (direccion alcista)))
)

(defrule micro-bos-bajista
   "El cierre actual rompe TODOS los mínimos históricos menos el margen"
   (hiperparametros (bos-margen ?margen))
   (vela (id 0) (close ?c0))
   (vela (id ?idx&~0))
   
   ;; Busca la inexistencia de una vela cuyo Low sea menor al Cierre 0 más el margen
   (not (vela (id ?id-hist&~0) (low ?l&:(<= ?l (+ ?c0 ?margen)))))
   =>
   (assert (microestado (patron bos) (direccion bajista)))
)

;; ========================================================================
;; 5. RUIDO (ESTADO POR DEFECTO)
;; ========================================================================

(defrule micro-ruido
   "Regla de descarte de baja prioridad"
   (declare (salience -10)) 
   (not (microestado))      
   =>
   (assert (microestado (patron ruido) (direccion neutro)))
)