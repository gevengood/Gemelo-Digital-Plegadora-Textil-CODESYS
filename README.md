# Prototipo de Tendido y Plegado Automático de Tela — Insuclínicos

Repositorio oficial del proyecto de **Automatización y Control de Procesos (2026-2)** — Universidad de La Sabana.

* 📖 **Wiki técnica completa:** 👉 **[Ir a la Wiki del Proyecto](https://github.com/gevengood/Gemelo-Digital-Plegadora-Textil-CODESYS/wiki)**
* 📊 **Presentación Pitch (Google Slides):** 👉 **[Abrir Presentación](https://docs.google.com/presentation/d/11WZ_Zf2Y2pb5ZqilpSzZr3aeZtRkJzwEJxSZrB2HEPU/edit?usp=sharing)**

> **Estado real:** Se desarrolló el diseño modular, el montaje físico preliminar (**304.000 COP**), el código Arduino UNO, `PLC_PRG` con **29 Rungs Ladder** y el lienzo HMI en CODESYS. **La implementación física integrada no funcionó durante pruebas y, por ello, no se completó la validación experimental ni el modelo digital en operación en vivo.**

## Estructura del Repositorio
* [`arduino/teclado_lcd.ino`](arduino/teclado_lcd.ino) — Adquisición teclado matricial `4x4` + pantalla `LCD 16x2` hacia ESP32 (`UART 9600 bps`).
* [`codesys/PLC_PRG.st`](codesys/PLC_PRG.st) — Declaración completa de variables y E/S IEC 61131-3 en CODESYS V3.5.
* [`docs/rungs_ladder.md`](docs/rungs_ladder.md) — Documentación y diagramas Markdown de los **29 Rungs Ladder (`0a–14d`)**.
