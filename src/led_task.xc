#include <platform.h>
#include <string.h>
#include <debug_print.h>

#include "led_task.h"
#include "ports.h"

// Функция управления тестовыми светодиодами
void TestLedControl(BOOL workMode, TEST_LED onoff) {
    if (workMode) {
        ledWork <: onoff;
        ledTest <: onoff; // дополнительный ток
    }
    else
        ledTest <: onoff;
}

// Задача формирования тестовых световых импульсов
void led_task0(server led_if i_led[ADC_NUM], client tile0_switches_if i_sw) {
    debug_printf("led_task0\n");

    unsigned switch_reg = i_sw.getSwitches(); // чтение DIP переключателя
    BOOL workMode = CHECK_SWITCH(switch_reg, SW_MODE); // режим работы

    TEST_LED state = TEST_LED_OFF;
    TestLedControl(workMode, state);

    timer tmr;
    unsigned next_tmr;
    tmr :> next_tmr;
    unsigned prev = (next_tmr / T_SMP) * T_SMP;
    next_tmr = prev + 128 * T_SMP; // первый импульс

    debug_printf("led_tmr %x\n", next_tmr);

    BOOL flags[3] = {FALSE, FALSE, FALSE}; // флаги прочитанных значений

    unsigned counter = 0; // счетчик состояний

    while (1) {
        [[ordered]]
        select {
        // машина состояний формирующая световые импульсы
        case tmr when timerafter(next_tmr) :> void:
            TestLedControl(workMode, state); // формирование импульса с минимальной задержкой

            switch (counter) {
            case 0: // подготовка задачи датчика к импульсу за одну выборку до импульса
                counter++;
                next_tmr += 2 * T_SMP;

                for (int i = 0; i < ADC_NUM; i++) {
                    flags[i] = TRUE;
                    i_led[i].Req();
                }
                break;
            case 1: // начало импульса
                counter++;
                next_tmr += TEST_DURATION;
//                debug_printf("LED %x\n", next_tmr);
                debug_printf("LED\n");
                break;
            default: // конец импульса
                counter = 0;
                next_tmr += workMode ? (LED_WORK_PERIOD - 2 * T_SMP - TEST_DURATION) : (LED_TEST_PERIOD - 2 * T_SMP - TEST_DURATION);
                break;
            }

            state = counter == 1 ? TEST_LED_ON : TEST_LED_OFF;

            break;

        // чтение состояния светодиода
        case i_led[unsigned x].isLed() -> BOOL led:
//            debug_printf("wasLed\n");
            led = flags[x];
            flags[x] = FALSE;
            break;

        // количество выборок АЦП до формирования отчета о тестов сигнале
        case i_led[unsigned x].TestPeriod() -> unsigned period:
            period = workMode ? FAIL_RATE_WORK - 1 : FAIL_RATE_TEST - 1;
            break;

        // Чтение нового режима работы
        case i_sw.Update():
            switch_reg = i_sw.getSwitches();
            workMode = CHECK_SWITCH(switch_reg, SW_MODE);
            break;
        }
    }
}
