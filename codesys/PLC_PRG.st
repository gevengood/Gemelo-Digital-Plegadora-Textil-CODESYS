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
