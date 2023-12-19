/* Модуль доступа к портам процессора */

#ifndef TILE0_TASK_H_
#define TILE0_TASK_H_

#include "my_types.h"
#include "defines.h"
#include "relay.h"
#include "indicator.h"

// Сброс watchdog таймера
void wdt_reset0();

/* Чтение DIP переключателя
 * результат    код выставленные на переключетеле режимов работы
 */
uint8_t GetSwitches0();

/* Интерфейс к задаче обеспечивающей доспут к порта процессора */
typedef interface tile0_resources_if {
    /* Управление реле
     * mask     маска реле
     * state    заданное состояние
     * */
    void relayControlMask(RELAY_MASK_T mask, BOOL state);

    /* Управление индикаторами
     * num      номер индикатора
     * state    заданное состояние
     * */
    void indControl(ind_num_t num, ind_state_t state);

    /* Чтение состояния индикаторов
     * num          номер индикатора
     * результат    текущее состояние
     * */
    ind_state_t indCheck(ind_num_t num);

    // сброс watchdog таймера
    void wdtReset();

    // оповещение об обновление режима работы
    [[notification]] slave void Update();

    // чтение кода выставленного на DIP переключателях
    [[clears_notification]] uint8_t getSwitches();
} tile0_resources_if;

// Интерфейс чтения режима работы выставленного на DIP переключателях
typedef interface tile0_switches_if {
    // Оповещение об изменение состояния
    [[notification]] slave void Update();

    // текущее состояние DIP переключателей
    [[clears_notification]] uint8_t getSwitches();
} tile0_switches_if;

/* Задача обеспечивающая доступ к переферии процессора
 * i_t0     первый интерфейс доступа к задаче
 * i_sw     второй интерфейс доступа к задаче
 */
[[combinable]]
void tile0_task(server tile0_resources_if i_t0, server tile0_switches_if i_sw[2]);

// Функция инициализации каналов
void InitChannels0();

#endif /* TILE0_TASK_H_ */
