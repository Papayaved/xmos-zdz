#include "app_task.h"
#include "defines.h"
#include "sensor_task.h"
#include "indicator.h"

static BOOL mask[ADC_NUM]; // маска используемых каналов: 1 - используется, 0 - не используется
static BOOL imp_ena[3]; // вкл/выкл влияния каналов 2 и 3 на канал 1
static BOOL imp[3]; // срабатывание вызвано влиянием
static unsigned delay2; // задержка реакции реле 3

// Чтение состояния DIP переключателя и инициализация параметров выбранного режима работы
static void ReadSwitches(client tile0_resources_if i_t0) {
    unsigned sw = i_t0.getSwitches();

    // вкл. индикатора режима
    IS_WORK_MODE(sw) ? i_t0.indControl(IND_MODE, IND_GREEN_ON) : i_t0.indControl(IND_MODE, IND_RED_ON);

    mask[0] = TRUE;
    mask[1] = CHECK_SWITCH(sw, SW2_OFF) != 0;
    mask[2] = CHECK_SWITCH(sw, SW3_OFF) != 0;

    imp_ena[1] = !CHECK_SWITCH(sw, SW2_TO_SW1);
    imp_ena[2] = !CHECK_SWITCH(sw, SW3_TO_SW1);

    delay2 = 100 * ONE_MS * !CHECK_SWITCH(sw, SW_DELAY1) + 200 * ONE_MS * !CHECK_SWITCH(sw, SW_DELAY2);
}

/* Получение битового поля флагов в соответствие с маской каналов */
static GOOSE_BITS toFlags(BOOL alarm[3], BOOL test[3], BOOL mask[3]) {
    return  (alarm[0] && mask[0] ? ALARM_BIT0 : 0) |
            (alarm[1] && mask[1] ? ALARM_BIT1 : 0) |
            (alarm[2] && mask[2] ? ALARM_BIT2 : 0) |
            ((test[0] && mask[0]) || (test[1] && mask[1]) || (test[2] && mask[2]) ? TEST_BIT : 0);
}

// Основная логика работы ЗДЗ
void app_task(
    server application_if i_app[n], unsigned n,
    client tile0_resources_if i_t0,
    server goose_if i_g)
{
    debug_printf("app_task\n");

    timer hold_tmr[ADC_NUM]; // таймеры удержания реле после срабатывания
    // todo: для синхронной работы нужно использовать 1 таймер

    unsigned next_hold[ADC_NUM]; // время до которого происходит удержание
    BOOL hold_ena[ADC_NUM] = {FALSE}; // вкл/выкл таймера удержания

    timer delay_tmr; // таймер задержки срабатывания реле 3
    unsigned next_delay; // время до которого происходит задержка
    BOOL delay_ena = FALSE; // вкл/выкл задержки

    SIGNAL sig[ADC_NUM] = {OFF}; // состояние сигналов с датчиков
    BOOL alarmPresent[ADC_NUM] = {FALSE}; // устройство в состояние срабатывания (вкл с sig отключается вместе с реле)
    BOOL testAbsent[ADC_NUM] = {FALSE}; // отсутствует тестовый сигнал
    GOOSE_BITS flags, flags_sent = NO_FLAGS_BIT; // текущее состояние, последнее посланное по сети состояние

    // Инициализыция индикаторов срабатывания
    i_t0.indControl(IND_CH1, IND_GREEN_OFF);
    i_t0.indControl(IND_CH2, IND_GREEN_OFF);
    i_t0.indControl(IND_CH3, IND_GREEN_OFF);
    i_t0.indControl(IND_MODE, IND_OFF);

    // Инициализация режима работы
    ReadSwitches(i_t0);

    // Чтение состояния тестовых сигналов после начальной инициализации
    testAbsent[0] = (i_t0.indCheck(0) & IND_RED_ON) != 0;
    testAbsent[1] = (i_t0.indCheck(1) & IND_RED_ON) != 0;
    testAbsent[2] = (i_t0.indCheck(2) & IND_RED_ON) != 0;

    flags = toFlags(alarmPresent, testAbsent, mask);
    debug_printf("FLAGS %x\n", flags);

    timer wd_timer; // таймер сброса внешнего watchdog таймера
    unsigned next_wdt; // следующий момент сброса

    // Начальная инициализация watchdog таймера
    wd_timer :> next_wdt;
    next_wdt += WDT_PERIOD;
    i_t0.wdtReset();

    debug_printf("app_tsk started\n");

    while (1) {
        [[ordered]]
        select {
            // конец сигнала Авария с датчика
            case i_app[unsigned x].reportAlarmOff(void):
                debug_printf("Sensor %x OFF\n", x);
                sig[x] = OFF;
                break;

            // начало сигнала Авария с датчика
            case i_app[unsigned x].reportAlarm(unsigned alarmType): // alarmType - don't used
                if (mask[x]) {
                    BOOL send_req;

                    debug_printf("Sensor %x ON Alarm %x\n", x, alarmType);

                    switch (x) { // x - номер АЦП
                    case 0:
                        i_t0.relayControlMask(RELAY_MSK_ALARM | RELAY_MSK_CH1, 1);

                        // таймер на отключение реле
                        hold_tmr[0] :> next_hold[0];
                        next_hold[0] += RELAY_HOLD;
                        hold_ena[0] = TRUE;

                        // срабатывание не вызвано влиянием
                        imp[1] = FALSE;
                        imp[2] = FALSE;

                        send_req = !alarmPresent[0]; // запрос посылки данных в сеть если состояние изменилось
                        alarmPresent[0] = TRUE;

                        break;
                    case 1:
                        if (imp_ena[1]) { // включено влияние канала 2 на канал 1 без задержки
                            i_t0.relayControlMask(RELAY_MSK_ALARM | RELAY_MSK_CH2 | RELAY_MSK_CH1, 1);

                            // таймер на отключение реле
                            hold_tmr[1] :> next_hold[1]; // порядок следования важен
                            hold_tmr[0] :> next_hold[0];
                            next_hold[1] += RELAY_HOLD;
                            next_hold[0] += RELAY_HOLD;
                            hold_ena[1] = TRUE;
                            hold_ena[0] = TRUE;

                            // срабатывание вызвано влияние канала 2
                            imp[1] = TRUE;
                            imp[2] = FALSE;

                            send_req = !alarmPresent[0] || !alarmPresent[1];
                            alarmPresent[0] = TRUE;
                            alarmPresent[1] = TRUE;
                        }
                        else {
                            i_t0.relayControlMask(RELAY_MSK_ALARM | RELAY_MSK_CH2, 1);

                            // таймер на отключение реле
                            hold_tmr[1] :> next_hold[1];
                            next_hold[1] += RELAY_HOLD;
                            hold_ena[1] = TRUE;

                            send_req = !alarmPresent[1]; // запрос посылки данных в сеть если состояние изменилось
                            alarmPresent[1] = TRUE;
                        }

                        break;
                    case 2:
                        i_t0.relayControlMask(RELAY_MSK_ALARM | RELAY_MSK_CH3, 1);

                        if (!delay_ena && imp_ena[2]) { // должен отработать по предыдышему срабатыванию
                            debug_printf("delay2 cnt\n");
                            delay_tmr :> next_delay;
                            next_delay += delay2;
                            delay_ena = TRUE; // delay2 timer enable
                        }

                        // таймер на отключение реле
                        hold_tmr[2] :> next_hold[2];
                        next_hold[2] += RELAY_HOLD;
                        hold_ena[2] = TRUE;

                        send_req = !alarmPresent[2]; // запрос посылки данных в сеть если состояние изменилось
                        alarmPresent[2] = TRUE;

                        break;
                    }

                    // светодиод поканальный было срабатывание
                    i_t0.indControl(x, IND_GREEN_ON);
                    sig[x] = ON;

                    flags = toFlags(alarmPresent, testAbsent, mask);
                    if (send_req) i_g.goose_rdy();
                }

                break;

        // Обработка окончания времени задержки влияния канала 3 на канал 1
        case delay_ena => delay_tmr when timerafter(next_delay) :> void:
            i_t0.relayControlMask(RELAY_MSK_CH1, 1);

            if (!alarmPresent[0]) {
                alarmPresent[0] = TRUE;
                flags = toFlags(alarmPresent, testAbsent, mask);
                i_g.goose_rdy();
            }

            delay_ena = FALSE; // timer disable

            hold_tmr[0] :> next_hold[0];
            next_hold[0] += RELAY_HOLD;
            hold_ena[0] = TRUE;

            // срабатывание вызвано влияние канала 3
            imp[1] = FALSE;
            imp[2] = TRUE;

            debug_printf("delay2 finish\n");

            break;

        // Обработка окончания времени удержания реле после срабатывания, если нет сигнала
        case (unsigned x = 0; x < ADC_NUM; x++) hold_ena[x] => hold_tmr[x] when timerafter(next_hold[x]) :> void:
            switch (x) {
            case 0:
                BOOL off =  sig[0] == OFF &&
                            (!imp_ena[1] || !alarmPresent[1]) &&
                            (!imp_ena[2] || !alarmPresent[2]);

                if (off) {
                    i_t0.relayControlMask(RELAY_MSK_CH1, 0);
                    hold_ena[0] = FALSE;
                    alarmPresent[0] = FALSE;
                }

                break;
            case 1:
                if (sig[1] == OFF) {
                    i_t0.relayControlMask(RELAY_MSK_CH2, 0);
                    hold_ena[1] = FALSE;
                    alarmPresent[1] = FALSE;

                    // отключение канала 0
                    if (imp[1]) {
                        imp[1] = FALSE;
                        i_t0.relayControlMask(RELAY_MSK_CH1, 0);
                    }
                }
                break;
            case 2:
                if (sig[2] == OFF) {
                    i_t0.relayControlMask(RELAY_MSK_CH3, 0);
                    hold_ena[2] = FALSE;
                    alarmPresent[2] = FALSE;

                    // отключение канала 0
                    if (imp[2]) {
                        imp[2] = FALSE;

                        if (delay2 == 0)
                            i_t0.relayControlMask(RELAY_MSK_CH1, 0);
                        else {
                            hold_tmr[0] :> next_hold[0];
                            next_hold[0] += delay2;
                        }
                    }
                }
                break;
            }

            flags = toFlags(alarmPresent, testAbsent, mask);

            if (hold_ena[x]) {
                debug_printf("Repeat timeout %x\n", x);
                hold_tmr[x] :> next_hold[x];
                next_hold[x] += RELAY_HOLD;
            }
            else {
                debug_printf("Finish timeout %x\n", x);
                i_g.goose_rdy();
            }

            break;

        // Обработка состояния тестовых сигналов в канале
        case i_app[unsigned x].reportTest(unsigned testDetected):
            //debug_printf("testDetected[%x] = %d\n", x, testDetected);
            testAbsent[x] = testDetected == 0; // testAbsent = 0 - OK, 1 - отказ
            flags = toFlags(alarmPresent, testAbsent, mask);

            if (mask[x]) {
                // реле Отказ
                i_t0.relayControlMask(RELAY_MSK_OTKAZ, !(flags & TEST_BIT));

                if (flags != flags_sent) // новый отказ
                    i_g.goose_rdy();

                // светодиод канальный
                testAbsent[x] ? i_t0.indControl(x, IND_RED_ON) : i_t0.indControl(x, IND_RED_OFF);
            }
            break;

        // чтение состояния флагов для отправки в сеть
        case i_g.get_flags() -> GOOSE_BITS flags:
            flags = toFlags(alarmPresent, testAbsent, mask);
            flags_sent = flags;
            debug_printf("read flags %x\n", flags);
            break;

        // изменилось состояние переключателей
        case i_t0.Update():
            ReadSwitches(i_t0);
            break;

        // сброс watchdog таймера с минимальным приоритетом, если основная задача зависла произойдет аппаратный сброс микроконтроллера
        case wd_timer when timerafter(next_wdt) :> void:
//            debug_printf("Main alive\n");
            i_t0.wdtReset();
            next_wdt += WDT_PERIOD;
            break;
        }
    }
}
