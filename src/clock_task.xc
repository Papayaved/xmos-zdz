#include "clock_task.h"
#include "defines.h"

//[[combinable]]
void clock_task(server clock_if i_clock) {
    debug_printf("clock_task\n");

    AlarmFlags f_alarm = NO_ALARM; // ���������� �������� ����� ����������� ��������

    timer goose_tmr; // ������ GOOSE ���������
    BOOL goose_ena = FALSE; // ���./����. GOOSE �������
    unsigned next_goose; // ������ ������� ���������� ������������ goose_tmr
    goose_tmr :> next_goose; // ������������� ����������

    uint32_t sec_cnt = 0; // ������� ������ � ������� ������ �������
    timer clock_tmr; // ��������� ������
    unsigned next_sec; // ������ ������� ���������� ������������ clock_tmr
    clock_tmr :> next_sec;
    next_sec += ONE_S; // ������������� ����������

    timer link_tmr; // ������ ������ Ethernet ����������
    BOOL link_ena = FALSE; // ���./����. link_tmr
    unsigned next_link; // ������ ������� ���������� ������������ link_tmr
    link_tmr :> next_link;
    next_link += LINK_T; // ������������� ����������

    while (1) {
        [[ordered]]
        select {
            case goose_ena => goose_tmr when timerafter(next_goose) :> void: // ���������� ������������ GOOSE �������
                goose_ena = 0; // auto disable
                f_alarm = f_alarm | GOOSE_ALARM;
                i_clock.Alarm();
                break;

            case i_clock.AlarmType() -> AlarmFlags flags: // ������ ������ ���� ������
                flags = f_alarm;
                f_alarm = NO_ALARM; // ������� ���� ������
                break;

            case i_clock.getSeconds() -> uint32_t sec: // get current time in seconds
                sec = sec_cnt;
                break;

            case i_clock.setGooseAlarm(unsigned msec): // ��������� ���������� ������� GOOSE ���������
//                debug_printf("AlarmTask: set alarm %d ms\n", msec);
                f_alarm = f_alarm & ~GOOSE_ALARM;

                unsigned period = msec * ONE_MS; // ������ � ������

                unsigned cur_time; // ������� �����
                goose_tmr :> cur_time; // ������ �������� �������

                if (goose_ena) {
                    next_goose += period;

                    if (next_goose - cur_time < period >> 1)
                        next_goose = cur_time + period; // ����� ��������� �����
                }
                else
                    next_goose = cur_time + period; // ����� ��������� �����

                goose_ena = msec != 0; // ��������� GOOSE �������, ����������� ���������� �� ������������

                break;

            case clock_tmr when timerafter(next_sec) :> void: // ���������� ���������� �������
                sec_cnt++;
                next_sec += ONE_S;
                f_alarm = f_alarm | CLOCK_ALARM;
                i_clock.Alarm();
                break;

            case link_ena => link_tmr when timerafter(next_link) :> void: // ���������� ������ ������ Ethernet ����������
                next_link += LINK_T;
                f_alarm = f_alarm | LINK_ALARM;
                i_clock.Alarm();
                break;

            case i_clock.LinkEna(BOOL ena): // ����./���. ������� ������ Ethernet ����������
                link_ena = ena;

                if (link_ena) {
                    link_tmr :> next_link;
                    next_link += LINK_T; // ��������� ������� ���������� ������������ �������
                }

                break;
        }
    }
 }
