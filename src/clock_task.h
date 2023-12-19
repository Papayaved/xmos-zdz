/* Задача в которой собраны таймеры Ethernet
 * goose_tmr    таймер GOOSE сообщений
 * clock_tmr    таймер секундных отсчетов относительного времени
 * link_tmr     таймер опроса состояния Ethernet
 */

#ifndef TIME_TASK_H_
#define TIME_TASK_H_
#include "all_libs.h"
#include "my_types.h"

/* Период опроса состояния линии связи во время поиска Ethernet соединения
 * При установившейся связи таймер отключен, проверка состояния идет вместе с отправкой GOOSE сообщений
 */
#define LINK_T (250 * ONE_MS)

// Типы звонков задачи
typedef enum {NO_ALARM = 0, CLOCK_ALARM = 1<<0, GOOSE_ALARM = 1<<1, LINK_ALARM = 1<<2} AlarmFlags;

// Интерфейс к задаче clock_task
typedef interface clock_if{
    /* вкл/выкл таймера проверки линии связи */
    void LinkEna(BOOL enable);

    /* Количество секунд прошедших с момента подачи питания */
    uint32_t getSeconds();

    // Оповещение о срабатывание одного или нескольких таймеров
    [[notification]] slave void Alarm();

    // Чтение типа сработавшего таймера, сброс оповещения
    [[clears_notification]] AlarmFlags AlarmType();

    /* Включение таймера GOOSE сообщений и установка нового периода, в мс
     * Таймер отключается автоматически после каждого срабатывания,
     * что удобно при пропуске сообщений
     * Метод сбрасывает оповещение всех таймеров!
     */
    [[clears_notification]] void setGooseAlarm(unsigned msec);
} clock_if;

/* Задача таймеров */
//[[combinable]]
 void clock_task(server clock_if i_clock);

#endif /* TIME_TASK_H_ */
