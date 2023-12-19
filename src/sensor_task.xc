#include "sensor_task.h"
#include "my_types.h"

#undef UP
#undef DUR
#undef SAT
#undef SATLEN

#define AVG_FILTER_WIDTH (2) // разрядность адреса
#define AVG_FILTER_LENGTH (1<<AVG_FILTER_WIDTH) // длина фильтра
#define AVG_FILTER_MASK (AVG_FILTER_LENGTH - 1) // маска адреса

// состояния датчика
typedef enum {ST_STABLE, ST_POS0, ST_POS1, ST_SIG, ST_NEG} SENSOR_STATE;

// Задача реализующая логику детектора аварийных вспышек света и детектора тестовых сигналов
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

    int adc; // текущее значение АЦП
    int adc_dly; // задерженное на одну выборку значение АЦП
    int fifo[AVG_FILTER_LENGTH]; // буфер FIFO для усредняющего фильтра
    unsigned wraddr = 0; // текущий адрес записи фильтра
    int avg; // текущее среднее значение
    int avg_stable; // среднее значение в состояние STABLE
    int avg_max; // максимальное среднее за время детектирования
    int amp; // амлитуда импульса
    int thld; // пороговое значение

    unsigned dly_cnt = 16; // время задержки
    unsigned cnt_max = 0; // счетчик детектора насыщения
    unsigned detector = 0; // счетчик длительности импульса
    SENSOR_STATE state = ST_STABLE; // текущее состояние датчика

    unsigned test_period = ~0U; // период формирования тестовых отчетов, в количестве выборок АЦП
    unsigned test_period_cnt = 0; // счетчик периода тестовых отсчетов
    unsigned led_cnt = 0; // счетчик обнаруженных тестовых сигналов
    unsigned led_frame = 0; // окно обнаружения тестовых сигналов

    test_period = i_led.TestPeriod(); // чтение режима работы

    // промывка буфера канала и загрузка данных в фильтр
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
            // обработка нового отчета АЦП
            case c_adc :> adc:
                i_osc.Add(adc); // отправка значения АЦП в задачу осциллографа

                // Усреднение
                wraddr &= AVG_FILTER_MASK;
                fifo[wraddr++] = adc_dly; // запись данных в FIFO
                adc_dly = adc; // линия задержки

                // расчет среднего значения для данных в FIFO
                avg = fifo[0];
                for (int i = 1; i < AVG_FILTER_LENGTH; i++)
                    avg += fifo[i];

                avg >>= AVG_FILTER_WIDTH;

                // Обнаружение насыщения, cnt_max in [0, UPMAXLEN]
                if (adc > SAT) {
                    if (cnt_max < SATLEN) cnt_max++;
                }
                else {
                    if (cnt_max > 0) cnt_max--;
                }

                if (cnt_max >= SATLEN) { // превышение UPMAXLEN (30) раз подряд
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
                    // состояние ожидания
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
                            dly_cnt = AVG_FILTER_LENGTH; // пропускаем 4 значения
                        }
                        break;

                    // обнаружен передний фронт заданной крутизны
                    case ST_POS0:
#ifdef ADC_PRN
                        debug_printf("%x THLD0 %d\n", num, thld);
#endif
                        if (led_frame) {
                            led_frame = 0;
                            led_cnt++; // обнаружен тестовый импульс
                        }

                        if (adc < thld)
                            state = ST_STABLE;
                        else { // сигнал не спал
                            // пересчитываем значение порога
                            thld = (adc + avg_stable) >> 1;
                            if (thld < avg_stable + UP) thld = avg_stable + UP;
                            detector++;

                            state = ST_POS1;

                            // ищем максимальное среднее за импульс
                            if (avg > avg_max)
                                avg_max = avg < SAT ? avg : SAT;

#ifdef ADC_PRN
                            debug_printf("%x THLD1 %d\n", num, thld);
#endif
                        }
                        break;

                    // считаем длительность сигнала
                    case ST_POS1:
                        if (led_frame) { // тестовый сигнал может быть во время аварийной вспышки
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
                                amp = (avg_max - avg_stable)>>2; // четверть амплитуды
//                                if (amp < UP) amp = UP;
                                thld = avg_max - amp;
                                i_app.reportAlarm(1);
                            }

                            if (avg > avg_max)
                                avg_max = avg < SAT ? avg : SAT;
                        }
                        break;

                    // ждем спада сигнала
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

                    // отрицательный импульс
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

                // Окно тестового импульса
                if (led_frame) led_frame--;

                // Формирование отчетов о наличие тестовых сигналов
                if (test_period_cnt > test_period) {
                    i_app.reportTest(led_cnt);
                    test_period_cnt = 0;
                    led_cnt = 0;
                }
                else
                    test_period_cnt++;

                break;

            // оповещените о формирование тестового импульса
            case i_led.Req():
                if (i_led.isLed())
                    led_frame = 16;
                else
                    test_period = i_led.TestPeriod();

                break;
        }
    }
}
