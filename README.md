# Contador Ascendente/Descendente Controlado por UART

Trabajo Práctico Final — Microarquitecturas y Softcore
Carrera de Especialización en Sistemas Embebidos — FIUBA

## Descripción

Contador de 4 bits (rango 0-15), ascendente/descendente, controlado por
comandos enviados desde una terminal serie (UART) al procesador ARM Cortex-A9
de una FPGA Zynq-7000 (placa Digilent Arty Z7-10). El procesador corre una
aplicación bare-metal en C que lee los comandos por consola y se comunica,
vía bus **AXI4-Lite**, con un IP Core custom diseñado en VHDL que contiene la
lógica de decodificación de comandos y el contador propiamente dicho.

La UART física es manejada íntegramente por el controlador de UART del
Processing System (PS) del Zynq — no hay ningún receptor UART implementado en
lógica programable.

### Comandos soportados

| Carácter | Acción |
|---|---|
| `+` | Incrementa el contador (wrap-around: 15 → 0) |
| `-` | Decrementa el contador (wrap-around: 0 → 15) |
| `R` / `r` | Resetea el contador a 0 |
| `A` / `a` | Alterna (toggle) el modo de conteo automático *(feature extra, no pedida por la consigna original)* |
| cualquier otro | Se ignora, sin efecto |

**Modo automático:** al activarse, el contador incrementa solo a un ritmo fijo
(~2 Hz por defecto, mediante un prescaler configurable). Cualquier comando
manual (`+`, `-`, `R`) desactiva el modo automático y toma control inmediato.

## Arquitectura

```
PC (consola serie) ──UART──▶ PS7 / Cortex-A9 ──C (bare-metal)──┐
                                                                 │ AXI4-Lite
                                                                 ▼
                                                    cmd_counter_ip_v1_0_S_AXI
                                                    ├── counter_logic_top
                                                    │   ├── cmd_decoder
                                                    │   └── counter
                                                    └── (protocolo AXI4-Lite estándar)
```

## Estructura del repositorio

```
├── vhdl/
│   ├── cmd_decoder.vhd              # Decodifica el byte ASCII en un comando de 3 bits
│   ├── counter.vhd                  # Contador 4 bits + modo automático (prescaler)
│   ├── counter_logic_top.vhd        # Une cmd_decoder + counter
│   ├── cmd_counter_ip_v1_0_S_AXI.vhd# Wrapper AXI4-Lite (registros + protocolo)
│   ├── tb_counter_logic_top.vhd     # Testbench: lógica interna, sin AXI
│   └── tb_cmd_counter_ip_v1_0_S_AXI.vhd # Testbench: transacciones AXI4-Lite reales
├── sw/
│   └── main.c                       # Aplicación bare-metal (Cortex-A9)
├── docs/
│   ├── Trabajo_Practico_Final_Quarin_Lautaro.docx
│   └── TPF_Contador_UART.pptx
└── README.md
```

## Mapa de registros AXI

Dirección base (asignada por Vivado): `0x43C00000`

| Offset | Registro | Acceso | Descripción |
|---|---|---|---|
| `0x0` | `CMD_REG` | Escritura | Byte ASCII del comando (`+`, `-`, `R`/`r`, `A`/`a`) |
| `0x4` | `COUNT_REG` | Lectura | Bits `[3:0]`: valor del contador. Bit `[4]`: estado del modo automático (1 = activo) |

## Cómo reproducir el proyecto

### 1. Simulación (no requiere Vivado con proyecto armado)

Con GHDL o el simulador de Vivado (XSim):

```bash
# Lógica interna (sin AXI)
ghdl -a --std=93 cmd_decoder.vhd counter.vhd counter_logic_top.vhd tb_counter_logic_top.vhd
ghdl -e --std=93 tb_counter_logic_top
ghdl -r --std=93 tb_counter_logic_top --stop-time=2000ns

# Wrapper AXI4-Lite completo
ghdl -a --std=93 cmd_decoder.vhd counter.vhd counter_logic_top.vhd cmd_counter_ip_v1_0_S_AXI.vhd tb_cmd_counter_ip_v1_0_S_AXI.vhd
ghdl -e --std=93 tb_cmd_counter_ip_v1_0_S_AXI
ghdl -r --std=93 tb_cmd_counter_ip_v1_0_S_AXI --stop-time=3000ns
```

Ambos testbenches deben terminar sin ningún `assertion error` — el mensaje
final esperado es `Testbench finalizado sin errores...` /
`Testbench AXI finalizado sin errores...`.

> Nota: los testbenches usan un `AUTO_TICK_DIVISOR` reducido (5 ciclos) para
> simular el modo automático en tiempos razonables. El valor por defecto en
> la implementación real es 50.000.000 ciclos (~2 Hz a 100 MHz).

### 2. Implementación en Vivado (2018.1)

1. Crear un proyecto nuevo para una Arty Z7-10 (`xc7z010clg400-1`), o partir
   de un proyecto base con el Processing System (PS7) + AXI Interconnect ya
   configurados.
2. Agregar los 4 archivos de `vhdl/` (sin los testbenches) como Design
   Sources.
3. Fijar `cmd_counter_ip_v1_0_S_AXI` como Top temporalmente, y empaquetarlo
   como IP custom (Tools ▸ Create and Package New IP ▸ *Package your current
   project*, con **"Include IP generated files"**, no `.xci`).
4. Revertir el Top a `system_wrapper`, agregar la IP empaquetada al Block
   Design, conectarla al AXI Interconnect (Connection Automation), y generar
   el bitstream.
5. Exportar el hardware (con bitstream) y abrir el proyecto en el SDK.

### 3. Software (Xilinx SDK)

1. Crear un Application Project (plantilla *Empty Application*, OS Platform
   *standalone*) apuntando al hardware exportado.
2. Reemplazar `main.c` por el de `sw/main.c`.
3. Compilar, programar la FPGA (bitstream) y correr/debuggear la aplicación
   sobre el Cortex-A9.
4. Monitorear la consola por UART (115200 baud, 8N1) con cualquier terminal
   serie (minicom, PuTTY, etc.).

## Simulación — casos validados

- Incremento y decremento normales.
- Comando de reset (`R`).
- Wrap-around en ambos extremos del rango (15→0 y 0→15).
- Rechazo de un carácter inválido, sin efecto sobre el contador.
- Activación del modo automático, con incrementos periódicos verificados.
- Desactivación del modo automático ante un comando manual.
- (Testbench AXI) Verificación del bit de estado del modo automático (bit 4
  del registro de lectura) a través de transacciones AXI reales.

Todos los casos anteriores fueron validados también en hardware real sobre
una Arty Z7-10.
