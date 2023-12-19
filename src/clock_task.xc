#include "clock_task.h"
#include "defines.h"

//[[combinable]]
void clock_task(server clock_if i_clock) {
    debug_printf("clock_task\n");

    AlarmFlags f_alarm = NO_ALARM; // переменная хранящая флаги сработавших таймеров

    timer goose_tmr; // таймер GOOSE сообщений
    BOOL goose_ena = FALSE; // вкл./откл. GOOSE таймера
    unsigned next_goose; // момент времени следующего срабатывания goose_tmr
    goose_tmr :> next_goose; // инициализация переменной

    uint32_t sec_cnt = 0; // счетчик секунд с момента подачи питания
    timer clock_tmr; // секундный таймер
    unsigned next_sec; // момент времени следующего срабатывания clock_tmr
    clock_tmr :> next_sec;
    next_sec += ONE_S; // инициализация переменной

    timer link_tmr; // таймер поиска Ethernet соединения
    BOOL link_ena = FALSE; // вкл./откл. link_tmr
    unsigned next_link; // момент времени следующего срабатывания link_tmr
    link_tmr :> next_link;
    next_link += LINK_T; // инициализация переменной

    while (1) {
        [[ordered]]
        select {
            case goose_ena => goose_tmr when timerafter(next_goose) :> void: // обработчик срабытывания GOOSE таймера
                goose_ena = 0; // auto disable
                f_alarm = f_alarm | GOOSE_ALARM;
                i_clock.Alarm();
                break;

            case i_clock.AlarmType() -> AlarmFlags flags: // чтение флагов типа звонка
                flags = f_alarm;
                f_alarm = NO_ALARM; // очистка всех флагов
                break;

            case i_clock.getSeconds() -> uint32_t sec: // get current time in seconds
                sec = sec_cnt;
                break;

            case i_clock.setGooseAlarm(unsigned msec): // установка следующего периода GOOSE сообщений
//                debug_printf("AlarmTask: set alarm %d ms\n", msec);
                f_alarm = f_alarm & ~GOOSE_ALARM;

                unsigned period = msec * ONE_MS; // период в тактах

                unsigned cur_time; // текущее время
                goose_tmr :> cur_time; // чтение текущего времени

                if (goose_ena) {
                    next_goose += period;

                    if (next_goose - cur_time < period >> 1)
                        next_goose = cur_time + period; // новая временная сетка
                }
                else
                    next_goose = cur_time + period; // новая временная сетка

                goose_ena = msec != 0; // включение GOOSE таймера, возможность отключения не используется

                break;

            case clock_tmr when timerafter(next_sec) :> void: // обработчик секундного таймера
                sec_cnt++;
                next_sec += ONE_S;
                f_alarm = f_alarm | CLOCK_ALARM;
                i_clock.Alarm();
                break;

            case link_ena => link_tmr when timerafter(next_link) :> void: // обработчик таймер поиска Ethernet соединения
                next_link += LINK_T;
                f_alarm = f_alarm | LINK_ALARM;
                i_clock.Alarm();
                break;

            case i_clock.LinkEna(BOOL ena): // откл./вкл. таймера поиска Ethernet соединения
                link_ena = ena;

                if (link_ena) {
                    link_tmr :> next_link;
                    next_link += LINK_T; // установка времени следующего срабатывания таймера
                }

                break;
        }
    }
 }
