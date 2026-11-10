# 2. Implementación en CODESYS V3.5 (`PLC_PRG`, Modelo y 29 Rungs Ladder)

[⬅️ Volver al Inicio](Home) | [📊 Ver Presentación (Google Slides)](https://docs.google.com/presentation/d/11WZ_Zf2Y2pb5ZqilpSzZr3aeZtRkJzwEJxSZrB2HEPU/edit?usp=sharing)

> **⚠️ Alcance del módulo de software:** El código de `PLC_PRG` y las **29 redes Ladder (`0a`–`14d`)** representan la lógica modular propuesta bajo **IEC 61131-3** (dividida en adquisición de fuerza/movimiento, trayectoria/supervisión de velocidad `vc = min{vperfil, vlim}`, estados de avance/sujeción/retorno e interfaz). **Dado que la implementación física integrada no funcionó, estas rutinas no llegaron a operar en lazo cerrado sobre el hardware real ni completaron el enlace operativo del gemelo digital.**

---

## 2.1 Código de Declaración (`PLC_PRG` — `VAR ... END_VAR`)

```iecst
PROGRAM PLC_PRG
VAR
	(* Botones HMI y selector de modo *)
	xInicio_HMI				: BOOL := FALSE;
	xPausa					: BOOL := FALSE;
	xReset					: BOOL := FALSE;
	xParo_HMI				: BOOL := FALSE;
	xModoAutomatico			: BOOL := TRUE;

	(* Entradas físicas previstas desde ESP32 / Modbus TCP *)
	xStart_GPIO36			: BOOL := FALSE;
	xParoNC_GPIO39			: BOOL := TRUE;		(* Contacto NC sano en reposo = TRUE *)
	rTensionFiltrada		: REAL := 10.0;		(* Celda HX711 DT:32 / SCK:33 en rodillo 2 *)
	rVelocidadLinea			: REAL := 30.0;		(* Encoder LPD3806 A:34 / B:35 *)
	rPosicionRegla			: REAL := 0.0;
	iTeclado_GPIO16			: INT := 0;			(* Consigna UART desde Arduino UNO *)

	(* Permisos de operación y finales de carrera *)
	xCeldaCargaOK			: BOOL := TRUE;
	xEncoderOK				: BOOL := TRUE;
	xParametrosOK			: BOOL := TRUE;
	xReglaEnOrigen			: BOOL := TRUE;
	xReglaEnDestino			: BOOL := FALSE;
	xTelaSujeta				: BOOL := TRUE;
	xTelaLiberada			: BOOL := FALSE;
	xMovimientoPermitido	: BOOL := TRUE;
	xMovimientoDetenido		: BOOL := TRUE;

	(* Parámetros de ciclo y lazo supervisor PID ilustrativo *)
	wCantidadPliegues		: WORD := 5;
	rSetpointTension		: REAL := 10.0;
	rTensionMaxima			: REAL := 50.0;
	rVelPerfil				: REAL := 30.0;
	rVelocidadPID			: REAL := 30.0;
	rKp						: REAL := 0.002;	(* Valores ilustrativos de polo s=-2; sin sintonizar en máquina *)
	rKi						: REAL := 0.001333;
	rKd						: REAL := 0.0001667;

	(* Máquina de estados, telemetría y alarmas *)
	iEstadoProceso			: INT := 0;
	wPlieguesHechos			: WORD := 0;
	rVelComandada			: REAL := 0.0;

	xInicio					: BOOL;
	xParoEmergencia			: BOOL;
	xSistemaListo			: BOOL;
	xEnEstadoCero			: BOOL;
	xProcesoActivo			: BOOL;
	xEstado10_Verificacion	: BOOL;
	xEstado20_Avance		: BOOL;
	xEstado30_Liberar		: BOOL;
	xEstado40_Retorno		: BOOL;
	xEstado50_Sujetar		: BOOL;
	xEstado60_Contar		: BOOL;
	xEstado70_Fin			: BOOL;

	xReglaAvanzando			: BOOL;
	xPIDHabilitado			: BOOL;
	xCmdLiberar				: BOOL;
	xReglaRetornando		: BOOL;
	xCmdSujetar				: BOOL;
	xPulsoConteo			: BOOL;
	xCantidadCompleta		: BOOL;
	xProcesoFinalizado		: BOOL;
	xSolicitudPausa			: BOOL;

	xUmbralTension			: BOOL;
	xTensionAlta			: BOOL;
	xAlarmaActiva			: BOOL;
	xFalloSecuencia			: BOOL;

	(* Salidas previstas hacia actuadores en ESP32 *)
	xNEMA_Enable_GPIO27		: BOOL;
	xNEMA_Dir_GPIO26		: BOOL;
	xTT1_IN1_GPIO14			: BOOL;
	xTT1_IN2_GPIO13			: BOOL;
	xTT2_IN3_GPIO17			: BOOL;
	xTT2_IN4_GPIO18			: BOOL;

	(* Bloques de flanco y conteo *)
	rtInicio				: R_TRIG;
	rtContar				: R_TRIG;
	CTU_Pliegues			: CTU;
END_VAR
```

---

## 2.2 Lógica Ladder Completa (`Rung 0a` al `Rung 14d`)

### Grupo 0–1: Arranque, Seguridad y Permiso General

#### Rung `0a` — Arranque del ciclo (HMI o pulsador físico)
Combina en lógica `OR` el botón `INICIAR` del HMI (`xInicio_HMI`) y el pulsador físico `NO` conectado al `GPIO 36` (`xStart_GPIO36`) para activar la señal `xInicio`.
```text
|--+--[ ] xInicio_HMI -----+--( ) xInicio--|
   +--[ ] xStart_GPIO36 ---+
```

#### Rung `0b` — Parada de emergencia (HMI o contacto físico NC)
Activa `xParoEmergencia` si se pulsa `PARO EMERGENCIA` en el HMI (`xParo_HMI`) o si se abre el contacto normalmente cerrado en `GPIO 39` (`NOT xParoNC_GPIO39`, lógica falla-segura).
```text
|--+--[ ] xParo_HMI -------+--( ) xParoEmergencia--|
   +--[/] xParoNC_GPIO39 --+
```

#### Rung `1` — Permiso general del sistema (`xSistemaListo`)
Habilita la operación únicamente cuando no hay paro de emergencia ni alarmas activas y todos los sensores/parámetros están válidos.
```text
|--[/] xParoEmergencia --[/] xAlarmaActiva --[ ] xCeldaCargaOK --[ ] xEncoderOK --[ ] xParametrosOK --( ) xSistemaListo--|
```

---

### Grupo 2–3: Estado Cero, Enclavamiento e Inicialización

#### Rung `2a` — Verificación de estado de reposo (`EQ`)
Comprueba que la variable `iEstadoProceso` sea exactamente `0` para autorizar un nuevo arranque.
```text
|  +---------------+
|--|      EQ       |--( ) xEnEstadoCero--|
   | iEstadoProceso|
   | 0             |
   +---------------+
```

#### Rung `2b` — Inicio y enclavamiento de `xProcesoActivo`
Enclava `xProcesoActivo` al detectar `xInicio` en estado `0`, manteniéndolo retenido hasta completar el ciclo (`xEstado70_Fin`), siempre que `xSistemaListo`, `xModoAutomatico` y `NOT xPausa` se cumplan.
```text
|--+--[ ] xInicio ---------[ ] xEnEstadoCero --+--[ ] xSistemaListo --[ ] xModoAutomatico --[/] xPausa --( ) xProcesoActivo--|
   +--[ ] xProcesoActivo --[/] xEstado70_Fin --+
```

#### Rung `2c` — Transición inicial al Estado 10 (`rtInicio : R_TRIG`)
En el flanco de subida de `xProcesoActivo`, setea el Estado 10 de verificación y limpia banderas previas de finalización.
```text
|                       +----------+
|--[ ] xProcesoActivo --| rtInicio |--+--(S) xEstado10_Verificacion--|
                        |  R_TRIG  |  |--(R) xEstado70_Fin-----------|
                        +----------+  +--(R) xProcesoFinalizado------|
```

#### Rung `3` — Estado 10: Verificación de condiciones iniciales
Verifica que la regla esté en origen y la tela sujeta con permiso activo para avanzar al Estado 20.
```text
|--[ ] xEstado10_Verificacion --[ ] xProcesoActivo --[ ] xReglaEnOrigen --[ ] xTelaSujeta --[ ] xSistemaListo --+--(S) xEstado20_Avance-------|
                                                                                                               +--(R) xEstado10_Verificacion-|
```

---

### Grupo 4–6: Avance de Regla, Lazo Supervisor (`MIN`) y Liberación

#### Rung `4a` — Estado 20: Comando de avance y habilitación del supervisor
Ordena el avance de la regla (`xReglaAvanzando`) y habilita el lazo de control (`xPIDHabilitado`) mientras no exista pausa ni bloqueo mecánico.
```text
|--[ ] xEstado20_Avance --[ ] xSistemaListo --[/] xPausa --[ ] xMovimientoPermitido --+--( ) xReglaAvanzando--|
                                                                                      +--( ) xPIDHabilitado---|
```

#### Rung `4b` — Selección supervisora de velocidad (`MIN`: $v_c = \min\{v_{\text{perfil}}, v_{\lim}\}$)
Implementa directamente la estrategia de supervisión de tensión sin alterar la longitud objetivo: toma el mínimo entre el perfil de desplazamiento (`rVelPerfil`) y el límite calculado por tensión (`rVelocidadPID`).
```text
|                       +---------------+
|--[ ] xPIDHabilitado --|EN  MIN     ENO|--
                        | rVelPerfil    |--> rVelComandada
                        | rVelocidadPID |
                        +---------------+
```

#### Rung `5` — Fin de carrera en destino
Al llegar la regla al destino (`xReglaEnDestino`) con movimiento detenido, transiciona del Estado 20 al Estado 30.
```text
|--[ ] xEstado20_Avance --[ ] xReglaEnDestino --[ ] xMovimientoDetenido --+--(S) xEstado30_Liberar--|
                                                                          +--(R) xEstado20_Avance---|
```

#### Rung `6a` — Estado 30: Orden de liberación de sujeción
Activa el comando `xCmdLiberar` para soltar la tela al finalizar el tendido del pliegue.
```text
|--[ ] xEstado30_Liberar --[ ] xSistemaListo --( ) xCmdLiberar--|
```

#### Rung `6b` — Confirmación de tela liberada
Cuando se confirma `xTelaLiberada`, pasa del Estado 30 al Estado 40 de retorno.
```text
|--[ ] xEstado30_Liberar --[ ] xTelaLiberada --+--(S) xEstado40_Retorno--|
                                               +--(R) xEstado30_Liberar--|
```

---

### Grupo 7–10: Retorno, Sujeción y Conteo de Pliegues

#### Rung `7a` — Estado 40: Retorno de la regla hacia el origen
Comanda el retorno de la regla con la tela liberada para no arrastrar el pliegue recién tendido.
```text
|--[ ] xEstado40_Retorno --[ ] xSistemaListo --[/] xPausa --[ ] xTelaLiberada --[ ] xMovimientoPermitido --( ) xReglaRetornando--|
```

#### Rung `7b` — Fin de retorno en origen
Detecta la llegada a origen con eje detenido para pasar al Estado 50 de sujeción.
```text
|--[ ] xEstado40_Retorno --[ ] xReglaEnOrigen --[ ] xMovimientoDetenido --+--(S) xEstado50_Sujetar--|
                                                                          +--(R) xEstado40_Retorno--|
```

#### Rung `8a` — Estado 50: Orden de sujeción de tela
Acciona los actuadores de sujeción (`xCmdSujetar`) antes de iniciar el siguiente pliegue.
```text
|--[ ] xEstado50_Sujetar --[ ] xSistemaListo --( ) xCmdSujetar--|
```

#### Rung `8b` — Confirmación de tela sujeta
Al confirmarse `xTelaSujeta`, transiciona al Estado 60 de conteo.
```text
|--[ ] xEstado50_Sujetar --[ ] xTelaSujeta --+--(S) xEstado60_Contar---|
                                             +--(R) xEstado50_Sujetar--|
```

#### Rung `9a` — Pulso de flanco para conteo (`rtContar : R_TRIG`)
Genera un pulso único por ciclo (`xPulsoConteo`) al entrar en Estado 60.
```text
|                         +----------+
|--[ ] xEstado60_Contar --| rtContar |--( ) xPulsoConteo--|
                          |  R_TRIG  |
                          +----------+
```

#### Rung `9b` — Contador ascendente de pliegues (`CTU_Pliegues : CTU`)
Incrementa `wPlieguesHechos` (`CV`) por cada pliegue terminado y activa `xCantidadCompleta` (`Q`) al alcanzar `wCantidadPliegues` (`PV`). Se reinicia con `xReset`.
```text
|                       +-------------------+
|--[ ] xPulsoConteo ----|CTU_Pliegues    Q  |--( ) xCantidadCompleta--|
   xReset            -> |RESET  CTU      CV |-> wPlieguesHechos
   wCantidadPliegues -> |PV                 |
                        +-------------------+
```

#### Rung `10a` — Bucle de ciclo cuando aún faltan pliegues
Si `NOT xCantidadCompleta`, reactiva el Estado 20 para ejecutar el siguiente pliegue.
```text
|--[ ] xEstado60_Contar --[/] xCantidadCompleta --(S) xEstado20_Avance--|
```

#### Rung `10b` — Finalización automática al completar los pliegues
Si `xCantidadCompleta` es verdadero, activa el Estado 70 y la bandera de fin de proceso.
```text
|--[ ] xEstado60_Contar --[ ] xCantidadCompleta --+--(S) xEstado70_Fin-------|
                                                  +--(S) xProcesoFinalizado--|
```

#### Rung `10c` — Limpieza del Estado 60
Resetea el estado transitorio `xEstado60_Contar` tras evaluar el contador.
```text
|--[ ] xEstado60_Contar --(R) xEstado60_Contar--|
```

---

### Grupo 11–13: Pausa, Reset y Supervisión de Sobretensión

#### Rung `11` — Registro de solicitud de pausa
Refleja el estado del selector de pausa (`xPausa`) en `xSolicitudPausa`.
```text
|--[ ] xPausa --( ) xSolicitudPausa--|
```

#### Rung `12a` — Reset completo de banderas de estado
Con `xReset` y movimiento detenido (`xMovimientoDetenido`), resetea todos los estados secuenciales del proceso.
```text
|--[ ] xReset --[ ] xMovimientoDetenido --+--(R) xProcesoActivo----------|
                                          |--(R) xEstado10_Verificacion--|
                                          |--(R) xEstado20_Avance--------|
                                          |--(R) xEstado30_Liberar-------|
                                          |--(R) xEstado40_Retorno-------|
                                          |--(R) xEstado50_Sujetar-------|
                                          |--(R) xEstado60_Contar--------|
                                          |--(R) xEstado70_Fin-----------|
                                          +--(R) xProcesoFinalizado------|
```

#### Rung `12b` — Reinicio numérico del estado (`MOVE`)
Restablece `iEstadoProceso := 0` durante el reset seguro del sistema.
```text
|                                         +-----------+
|--[ ] xReset --[ ] xMovimientoDetenido --|EN MOVE ENO|--
                                          | 0         |--> iEstadoProceso
                                          +-----------+
```

#### Rung `13a` — Comparación de umbral de sobretensión (`GE`)
Evalúa si la fuerza filtrada (`rTensionFiltrada`) supera o iguala `rTensionMaxima`.
```text
|  +-----------------+
|--|       GE        |--( ) xUmbralTension--|
   | rTensionFiltrada|
   | rTensionMaxima  |
   +-----------------+
```

#### Rung `13b` — Enclavamiento de alarma por sobretensión
Retiene la alarma (`xTensionAlta`, `xAlarmaActiva`, `xFalloSecuencia`) hasta que el operario presione `RESET` (`NOT xReset`).
```text
|--+--[ ] xUmbralTension --+--[/] xReset --+--( ) xTensionAlta----|
   +--[ ] xTensionAlta ----+               |--( ) xAlarmaActiva---|
                                           +--( ) xFalloSecuencia-|
```

---

### Grupo 14: Salidas Físicas Previstas hacia Actuadores (`ESP32`)

#### Rung `14a` — Habilitación del driver `NEMA 17` (`GPIO 27`)
Habilita el driver del motor paso a paso tanto en avance como en retorno de la regla.
```text
|--+--[ ] xReglaAvanzando ---+--( ) xNEMA_Enable_GPIO27--|
   +--[ ] xReglaRetornando --+
```

#### Rung `14b` — Sentido de giro del `NEMA 17` (`GPIO 26`)
Fija la dirección física del eje lineal (`TRUE` al avanzar, `FALSE` al retornar). Los pulsos `STEP` en `GPIO 25` se generan en el ESP32 según `rVelComandada`.
```text
|--[ ] xReglaAvanzando --( ) xNEMA_Dir_GPIO26--|
```

#### Rung `14c` — Puente H `HW-094`: Giro de sujeción (`GPIO 14` y `17`)
Activa las entradas `IN1` e `IN3` de ambos actuadores de sujeción con enclavamiento excluyente (`NOT xCmdLiberar`).
```text
|--[ ] xCmdSujetar --[/] xCmdLiberar --+--( ) xTT1_IN1_GPIO14--|
                                       +--( ) xTT2_IN3_GPIO17--|
```

#### Rung `14d` — Puente H `HW-094`: Giro de liberación (`GPIO 13` y `18`)
Activa las entradas inversas `IN2` e `IN4` con enclavamiento excluyente (`NOT xCmdSujetar`) para liberar la tela.
```text
|--[ ] xCmdLiberar --[/] xCmdSujetar --+--( ) xTT1_IN2_GPIO13--|
                                       +--( ) xTT2_IN4_GPIO18--|
```
