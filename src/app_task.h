// Модуль описывающий основную логику работы устройства

#ifndef APP_TASK_H_
#define APP_TASK_H_

#include "tile0_task.h"
#include "goose.h"

/* Интерфейс датчиков с основной программой */
typedef interface application_if {
    /* количество детектированных тестовых сигналов */
    void reportTest(unsigned testDetected);

    /* детектировано срабатывание */
    void reportAlarm(unsigned alarmType);

    /* Конец срабатывания */
    void reportAlarmOff(void);
} application_if;

/* Основная программа работы ЗДЗ
 * application_if       интерфейс с датчиками
 * tile0_resources_if   интерфейс с портами ввода-вывода
 * goose_if             интерфейс c сетевой задачей для отправки информационных сообщений GOOSE
 */
// todo: эфективнее было бы интегрировать работу с портами в основную программу, но это вызывает конфликт ресурсов по непонятным причинам
void app_task(
    server application_if i_app[n], unsigned n,
    client tile0_resources_if i_t0,
    server goose_if i_g);

#endif /* ZDZ_MAIN_H_ */
