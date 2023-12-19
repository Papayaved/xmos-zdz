#include <platform.h>
#include <string.h>
#include <debug_print.h>

#include "ports.h"

#include "tile0_task.h"
#include "adc.h"
#include "led_task.h"

/* Reset watchdog timer
 * Watchdog timer resets by any signal edge
 */
void wdt_reset0() {
    static int wd_reg;
    wd_reg = !wd_reg;
    wd <: wd_reg;
//    debug_printf("WDT\n");
}

/* Задача обеспечивающая доступ к переферии процессора */
[[combinable]]
void tile0_task(server tile0_resources_if i_t0, server tile0_switches_if i_sw[2]) {
    debug_printf("tile0_task\n");

    uint8_t switch_reg;
    switches :> switch_reg;

    wdt_reset0();

    while (1) {
        select {
        case i_t0.relayControlMask(RELAY_MASK_T mask, BOOL state):
//            debug_printf("relay\n");
            if (!IS_WORK_MODE(switch_reg))
                mask = mask & ~(RELAY_MSK_CH1 | RELAY_MSK_CH2 | RELAY_MSK_CH3);

            relayControlMask(mask, state);
            break;

        case i_t0.indControl(ind_num_t num, ind_state_t state):
//            debug_printf("indControl\n");
            indControl(num, state);
            break;

        case i_t0.indCheck(ind_num_t num) -> ind_state_t value:
//            debug_printf("indCheck\n");
            value = indCheck(num);
            break;

        case i_t0.getSwitches() -> uint8_t value:
//            debug_printf("switch_reg\n");
            value = switch_reg;
            break;

        case i_sw[unsigned x].getSwitches() -> uint8_t value:
//            debug_printf("switch_reg\n");
            value = switch_reg;
            break;

        // изменилось состояние переключателей режима
        case switches when pinsneq(switch_reg) :> switch_reg:
//            debug_printf("switches\n");
            soft_reset0();

            i_t0.Update();

            for (int i = 0; i < 2; i++)
                i_sw[i].Update();

            break;

        case i_t0.wdtReset():
            wdt_reset0();
            break;
        }
    }
}

// Функция инициализации каналов
#define COEF (5 * UP)
void InitChannels0() { // function used once before start parallel tasks
    debug_printf("InitChannels0\n");

    int buf[ADC_NUM][2];
    unsigned sw;
    BOOL mask[ADC_NUM];
    BOOL otkaz;

    unsafe {
        int control;
        int adc[ADC_NUM];

        volatile int* const unsafe p_ctrl = &control;
        volatile int* const unsafe p_adc[ADC_NUM] = {&adc[0], &adc[1], &adc[2]};

        memset(buf, 0, sizeof(buf));
        *p_ctrl = 1;

        par {
            sinc3m(adcIn_1, p_ctrl, p_adc[0]);
            sinc3m(adcIn_2, p_ctrl, p_adc[1]);
            sinc3m(adcIn_3, p_ctrl, p_adc[2]);

            {
                TestLedControl(TRUE, TEST_LED_OFF);
                delay_ticks(2 * T_SMP);
//                delay_microseconds(100);

                for (int i = 0; i < LEN; i++) {
                    delay_ticks(T_SMP);
//                    delay_microseconds(50);

                    if (i == LEN / 3)
                        TestLedControl(TRUE, TEST_LED_ON);

                    for (int k = 0; k < ADC_NUM; k++) {
                        if (i < 5)
                            buf[k][0] += *p_adc[k];

                        if (i > LEN - 6)
                            buf[k][1] += *p_adc[k];
                    }
                }

                TestLedControl(TRUE, TEST_LED_OFF);
                *p_ctrl = 0;

                switches :> sw;
                mask[0] = TRUE;
                mask[1] = CHECK_SWITCH(sw, SW2_OFF) != 0;
                mask[2] = CHECK_SWITCH(sw, SW3_OFF) != 0;

                otkaz = FALSE;

                for (int k = 0; k < ADC_NUM; k++)
                    if (mask[k]) {
                        if (buf[k][1] - buf[k][0] < COEF) {
                            indControl(k, IND_RED_ON);
                            otkaz = TRUE;
                        }
                        else
                            indControl(k, IND_RED_OFF);
                    }

                relayControlMask(RELAY_MSK_OTKAZ, !otkaz);
            }
        }
    }

    debug_printf("InitChannels0 FIN\n");
}
