#include "xil_io.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "xuartlite.h"
#include <stdint.h>

#define BRAM1_BASE_ADDR    0xC0000000
#define BRAM2_BASE_ADDR    0xC2000000
#define BRAM3_BASE_ADDR    0xC4000000
#define SOLVER_IP_ADDR     0x44A00000

#define REG_START          0x00
#define REG_DONE           0x04
#define REG_STEPS          0x08
#define REG_CLK_COUNTER	   0x0C

#define REG_DT             0x1C
#define REG_N              0x20
#define REG_N_CLAUSE       0x24

#define UART_DEVICE_ID XPAR_UARTLITE_0_DEVICE_ID
#define MAGIC_WORD         0x11111111

static XUartLite Uart;

static void uart_recv_exact(uint8_t *buf, unsigned len) {
    unsigned total = 0;
    while (total < len) {
        total += XUartLite_Recv(&Uart, buf + total, len - total);
    }
}

static uint32_t recv_u32(void) {
    uint8_t b[4];
    uart_recv_exact(b, 4);
    return ((uint32_t)b[0]) |
           ((uint32_t)b[1] << 8) |
           ((uint32_t)b[2] << 16) |
           ((uint32_t)b[3] << 24);
}

int main() {

    uint32_t n, n_clause;

    XUartLite_Initialize(&Uart, UART_DEVICE_ID);
    XUartLite_ResetFifos(&Uart);

    // receive header
    uint32_t magic = recv_u32();
    n = recv_u32();
    n_clause = recv_u32();

    if (magic != MAGIC_WORD) {
        xil_printf("bad magic\n\r");
        return 0;
    }

    xil_printf("n=%lu n_clause=%lu\n\r", n, n_clause);

    // receive clauses -> write to BRAM
    for (uint32_t i = 0; i < n_clause; i++) {
        uint32_t lit1 = recv_u32();
        uint32_t lit2 = recv_u32();
        uint32_t lit3 = recv_u32();

        Xil_Out32(BRAM1_BASE_ADDR + (i * 4), lit1);
        Xil_Out32(BRAM2_BASE_ADDR + (i * 4), lit2);
        Xil_Out32(BRAM3_BASE_ADDR + (i * 4), lit3);
    }

    xil_printf("upload done\n\r");

    // set registers
    Xil_Out32(SOLVER_IP_ADDR + REG_DT, 4);
    Xil_Out32(SOLVER_IP_ADDR + REG_N, n);
    Xil_Out32(SOLVER_IP_ADDR + REG_N_CLAUSE, n_clause);

    // start solver
    Xil_Out32(SOLVER_IP_ADDR + REG_START, 1);

    // wait done
    while (Xil_In32(SOLVER_IP_ADDR + REG_DONE) == 0);

    xil_printf("done\n\r");

    uint32_t steps = Xil_In32(SOLVER_IP_ADDR + REG_STEPS);
    uint32_t clk_counter  = Xil_In32(SOLVER_IP_ADDR + REG_CLK_COUNTER);

    xil_printf("steps=%lu\n\r", steps);
    xil_printf("clk_counter=%08lx\n\r", clk_counter);

    Xil_Out32(SOLVER_IP_ADDR + REG_START, 0);

    xil_printf("donezo\n\r");

    return 0;
}

