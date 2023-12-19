#include "sensor_task.h"
#include "my_types.h"

#undef UP
#undef DUR
#undef SAT
#undef SATLEN

#define AVG_FILTER_WIDTH (2) // ����������� ������
#define AVG_FILTER_LENGTH (1<<AVG_FILTER_WIDTH) // ����� �������
#define AVG_FILTER_MASK (AVG_FILTER_LENGTH - 1) // ����� ������

// ��������� �������
typedef enum {ST_STABLE, ST_POS0, ST_POS1, ST_SIG, ST_NEG} SENSOR_STATE;

// ������ ����������� ������ ��������� ��������� ������� ����� � ��������� �������� ��������
void sensor_task(
    int num,
    const sens_param_t param,
    streaming chanend c_adc,
    client application_if i_app,
    client osc_if i_osc,
    client led_if i_led
) {
    const int& UP = param.up;
    const unsigned& DUR = param.dur;
    const int& SAT = param.sat;
    const unsigned& SATLEN = param.sat_len;

    debug_printf("sens_tsk %x: up %d, dur %d, sat %d, sat_len %d\n",\
            num, UP, DUR, SAT, SATLEN);

    int adc; // ������� �������� ���
    int adc_dly; // ����������� �� ���� ������� �������� ���
    int fifo[AVG_FILTER_LENGTH]; // ����� FIFO ��� ������������ �������
    unsigned wraddr = 0; // ������� ����� ������ �������
    int avg; // ������� ������� ��������
    int avg_stable; // ������� �������� � ��������� STABLE
    int avg_max; // ������������ ������� �� ����� ��������������
    int amp; // �������� ��������
    int thld; // ��������� ��������

    unsigned dly_cnt = 16; // ����� ��������
    unsigned cnt_max = 0; // ������� ��������� ���������
    unsigned detector = 0; // ������� ������������ ��������
    SENSOR_STATE state = ST_STABLE; // ������� ��������� �������

    unsigned test_period = ~0U; // ������ ������������ �������� �������, � ���������� ������� ���
    unsigned test_period_cnt = 0; // ������� ������� �������� ��������
    unsigned led_cnt = 0; // ������� ������������ �������� ��������
    unsigned led_frame = 0; // ���� ����������� �������� ��������

    test_period = i_led.TestPeriod(); // ������ ������ ������

    // �������� ������ ������ � �������� ������ � ������
    while (dly_cnt--) {
        c_adc :> adc;
        wraddr &= AVG_FILTER_MASK;
        fifo[wraddr++] = adc_dly;
        adc_dly = adc;
    }

    i_led.isLed();

    while (1) {
        [[ordered]]
        select {
            // ��������� ������ ������ ���
            case c_adc :> adc:
                i_osc.Add(adc); // �������� �������� ��� � ������ ������������

                // ����������
                wraddr &= AVG_FILTER_MASK;
                fifo[wraddr++] = adc_dly; // ������ ������ � FIFO
                adc_dly = adc; // ����� ��������

                // ������ �������� �������� ��� ������ � FIFO
                avg = fifo[0];
                for (int i = 1; i < AVG_FILTER_LENGTH; i++)
                    avg += fifo[i];

                avg >>= AVG_FILTER_WIDTH;

                // ����������� ���������, cnt_max in [0, UPMAXLEN]
                if (adc > SAT) {
                    if (cnt_max < SATLEN) cnt_max++;
                }
                else {
                    if (cnt_max > 0) cnt_max--;
                }

                if (cnt_max >= SATLEN) { // ���������� UPMAXLEN (30) ��� ������
                    thld = avg_max = SAT;
                    avg_stable = SAT;
                    detector = 0;

                    if (state != ST_SIG) {
                        i_app.reportAlarm(2);
                        i_osc.Trigger();
                        state = ST_SIG;
                    }
                }
                else
                    switch (state) {
                    // ��������� ��������
                    case ST_STABLE:
                        if (adc > avg + UP) { // raise edge
                            state = ST_POS0;
                            thld = avg_max = adc;
                            avg_stable = avg;
                            detector = 0;
                            i_osc.Trigger();
                        }
                        else if (adc < avg - UP) { // fall edge
                            state = ST_NEG;
                            avg_stable = avg;
                            dly_cnt = AVG_FILTER_LENGTH; // ���������� 4 ��������
                        }
                        break;

                    // ��������� �������� ����� �������� ��������
                    case ST_POS0:
#ifdef ADC_PRN
                        debug_printf("%x THLD0 %d\n", num, thld);
#endif
                        if (led_frame) {
                            led_frame = 0;
                            led_cnt++; // ��������� �������� �������
                        }

                        if (adc < thld)
                            state = ST_STABLE;
                        else { // ������ �� ����
                            // ������������� �������� ������
                            thld = (adc + avg_stable) >> 1;
                            if (thld < avg_stable + UP) thld = avg_stable + UP;
                            detector++;

                            state = ST_POS1;

                            // ���� ������������ ������� �� �������
                            if (avg > avg_max)
                                avg_max = avg < SAT ? avg : SAT;

#ifdef ADC_PRN
                            debug_printf("%x THLD1 %d\n", num, thld);
#endif
                        }
                        break;

                    // ������� ������������ �������
                    case ST_POS1:
                        if (led_frame) { // �������� ������ ����� ���� �� ����� ��������� �������
                            led_frame = 0;
                            led_cnt++;
                        }

                        if (adc < thld)
                            state = ST_STABLE;
                        else {
                            detector++;

                            if (detector >= DUR) { // holds 12 times
                                state = ST_SIG;
                                detector = 0;
                                amp = (avg_max - avg_stable)>>2; // �������� ���������
//                                if (amp < UP) amp = UP;
                                thld = avg_max - amp;
                                i_app.reportAlarm(1);
                            }

                            if (avg > avg_max)
                                avg_max = avg < SAT ? avg : SAT;
                        }
                        break;

                    // ���� ����� �������
                    case ST_SIG:
                        if (led_frame) {
                            led_frame = 0;
                            led_cnt++;
                        }

                        if (avg < thld) { // fall
                            state = ST_STABLE;
                            i_app.reportAlarmOff();
#ifdef ADC_PRN
                            debug_printf("%x SIG %d\n", num, led_cnt);
#endif
                        }
                        else {
                            detector++;

                            if (detector >= DUR) { // holds 12 times
                                detector = 0;
                                thld = avg_max - amp;
                            }

                            if (avg > avg_max)
                                avg_max = avg < SAT ? avg : SAT;
                        }
                        break;

                    // ������������� �������
                    case ST_NEG:
                        if (adc < avg)
                            dly_cnt = AVG_FILTER_LENGTH;
                        else if (dly_cnt) {// delay
                            dly_cnt--;

                            if (adc > avg + UP && adc > avg_stable + UP) { // front and level
                                state = ST_POS0;
                                thld = avg_max = adc;
                                detector = 0;
                                i_osc.Trigger();
                            }
                        }
                        else {
                            state = ST_STABLE;
#ifdef ADC_PRN
                            debug_printf("%x NEG\n", num);
#endif
                        }
                        break;
                    }

                // ���� ��������� ��������
                if (led_frame) led_frame--;

                // ������������ ������� � ������� �������� ��������
                if (test_period_cnt > test_period) {
                    i_app.reportTest(led_cnt);
                    test_period_cnt = 0;
                    led_cnt = 0;
                }
                else
                    test_period_cnt++;

                break;

            // ����������� � ������������ ��������� ��������
            case i_led.Req():
                if (i_led.isLed())
                    led_frame = 16;
                else
                    test_period = i_led.TestPeriod();

                break;
        }
    }
}
