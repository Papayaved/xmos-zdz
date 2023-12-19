/* Модуль формирования тестовыми световых импульсов */

#ifndef LED_TASK_H_
#define LED_TASK_H_

#include "my_types.h"
#include "defines.h"
#include "tile0_task.h"

// Состояние тестового светодиода
typedef enum {TEST_LED_OFF, TEST_LED_ON} TEST_LED;

// Интерфейс с задачей управления тестовыми светодиодами
typedef interface led_if {
    // чтение длительности тестового периода
    unsigned TestPeriod();

    // запрос чтения
    [[notification]] slave void Req(void);

    /* Чтение состояния тестового светодиода
     * TRUE     включен
     * FALSE    отключен
     */
    [[clears_notification]] BOOL isLed();
} led_if;

/* Задача формирования тестовых световых импульсов
 * i_led    интерфейс к датчикам
 * i_sw     интерфейс к DIP переключетлю задающему режим работы
 * */
void led_task0(server led_if i_led[ADC_NUM], client tile0_switches_if i_sw);

/* Функция управления тестовыми светодиодами
 * workMode     режим работы
 * onoff        состояние светодиода
 */
void TestLedControl(BOOL workMode, TEST_LED onoff);

#endif /* LED_TASK_H_ */
