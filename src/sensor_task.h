/* Модуль датчиков */

#ifndef SENSOR_H_
#define SENSOR_H_

#include "all_libs.h"
#include "defines.h"

#include "app_task.h"
#include "led_task.h"
#include "osc_task.h"

// включение отладочной печати
#define ADC_PRN

// Состоние сигнала датчика
typedef enum {OFF, ON} SIGNAL;

typedef struct {
    int up;
    unsigned dur;
    int sat;
    unsigned sat_len;
} sens_param_t;

/* Задача реализующая логику детектора аварийных вспышек света и детектора тестовых сигналов
 * num      номер экземпляра задачи
 * param    локальные копии параметров работы датчиков
 * c_adc    канал от задачи АЦП
 * i_app    интерфейс к исполнительному устройству
 * i_osc    интерфейс к задаче осциллографа
 * i_led    интерфейс к задаче формирования тестовых сигналов
 */
void sensor_task(
    int num,
    const sens_param_t param,
    streaming chanend c_adc,
    client application_if i_app,
    client osc_if i_osc,
    client led_if i_led
);

#endif /* SENSOR_H_ */
