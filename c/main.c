/*
 * main.c - TPF: contador ascendente/descendente controlado por UART (via AXI)
 *
 * Flujo:
 *   1) Lee un caracter desde la consola serie (UART del PS, misma que usaron
 *      los labs anteriores).
 *   2) Si es un comando valido ('+', '-', 'R'/'r', 'A'/'a'), lo escribe en el
 *      registro de comando del IP (offset 0x0).
 *   3) Lee el registro de contador (offset 0x4) y lo muestra por consola.
 *   4) Si el caracter no es un comando valido, avisa y no hace nada.
 *
 * Modo automatico (feature extra, no pedida por la consigna original):
 *   - 'A'/'a' alterna (toggle) el modo automatico en hardware: el contador
 *     empieza a incrementar solo, a un ritmo fijo (prescaler en counter.vhd).
 *   - Mientras el modo automatico esta activo, este programa entra en un
 *     loop que va imprimiendo el contador cada vez que cambia, sin bloquear
 *     la consola -- en cuanto llega un caracter nuevo, sale del loop y lo
 *     procesa como cualquier otro comando (que ademas apaga el modo auto).
 *   - El bit 4 del registro de lectura (offset 0x4) indica si el modo
 *     automatico esta activo (1) o no (0); los bits [3:0] son el contador.
 */

#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xuartps_hw.h"
#include "sleep.h"

/* Base del IP, generada automaticamente por Vivado/SDK a partir del Block Design */
#define CMD_COUNTER_BASEADDR   XPAR_CMD_COUNTER_IP_0_BASEADDR

/* Mapa de registros dentro del IP (ver cmd_counter_ip_v1_0_S_AXI.vhd) */
#define CMD_REG_OFFSET      0x0   /* escritura: byte ASCII del comando   */
#define COUNT_REG_OFFSET    0x4   /* lectura: contador + bit de auto_mode */

#define COUNTER_MASK        0xF   /* contador de 4 bits: bits [3:0]      */
#define AUTO_MODE_BIT       0x10  /* bit de estado del modo auto: bit [4] */

/* Cada cuantos milisegundos se revisa si el contador cambio en modo auto */
#define AUTO_POLL_MS        200

/* Lee el registro de contador y separa valor + estado de auto_mode */
static u32 read_counter(void)
{
    return Xil_In32(CMD_COUNTER_BASEADDR + COUNT_REG_OFFSET);
}

/* Envia un comando (byte ASCII) al registro de comando del IP */
static void send_command(char c)
{
    Xil_Out32(CMD_COUNTER_BASEADDR + CMD_REG_OFFSET, (u32)c);
}

/* Bucle no bloqueante: mientras el modo automatico este activo y no haya
 * llegado un caracter nuevo por consola, va imprimiendo el contador cada
 * vez que cambia. Vuelve apenas hay un caracter nuevo esperando, o si el
 * modo automatico se apago solo (por las dudas). */
static void auto_mode_loop(void)
{
    u32 reg_value;
    u32 last_count = read_counter() & COUNTER_MASK;

    xil_printf("Modo automatico activado. Presione cualquier tecla para detenerlo.\r\n");
    xil_printf("Contador: %d\r\n", last_count);

    while (1) {
        /* Chequeo no bloqueante: ¿hay un byte nuevo esperando en la UART? */
        if (XUartPs_IsReceiveData(STDIN_BASEADDRESS)) {
            break;
        }

        reg_value = read_counter();

        /* Si el hardware ya no reporta auto_mode activo, no seguimos */
        if ((reg_value & AUTO_MODE_BIT) == 0) {
            xil_printf("Modo automatico se desactivo.\r\n");
            break;
        }

        if ((reg_value & COUNTER_MASK) != last_count) {
            last_count = reg_value & COUNTER_MASK;
            xil_printf("Contador: %d\r\n", last_count);
        }

        usleep(AUTO_POLL_MS * 1000);
    }
}

int main()
{
    char c;
    u32 reg_value;

    xil_printf("\r\n=== TPF: Contador UART (+/-/R/A) ===\r\n");
    xil_printf("'+' incrementa, '-' decrementa, 'R' resetea, 'A' modo automatico\r\n");

    while (1) {
        xil_printf("\r\n> ");
        c = inbyte();
        xil_printf("%c\r\n", c);

        if (c == '+' || c == '-' || c == 'R' || c == 'r' || c == 'A' || c == 'a') {
            send_command(c);

            if (c == 'A' || c == 'a') {
                /* Dar un instante a que el registro de estado se actualice */
                usleep(1000);
                reg_value = read_counter();

                if (reg_value & AUTO_MODE_BIT) {
                    auto_mode_loop();
                } else {
                    xil_printf("Modo automatico desactivado. Contador: %d\r\n",
                               reg_value & COUNTER_MASK);
                }
            } else {
                reg_value = read_counter();
                xil_printf("Contador: %d\r\n", reg_value & COUNTER_MASK);
            }
        } else {
            xil_printf("Comando invalido. Use '+', '-', 'R' o 'A'.\r\n");
        }
    }

    return 0;
}
