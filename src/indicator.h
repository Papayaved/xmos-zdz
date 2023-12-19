/* Модуль индикаторов состояния
 * Состояния канальных индикаторов (1, 2, 3):
 *      выкл         канал исправен, срабатываний не было
 *      красный      отказ
 *      зеленный     было срабатывание
 *      желтый       отказ и было срабатывание (не штатное состояние)
 *
 * Состояние индикатора режима работы (4):
 *      выкл        нет питания
 *      красный     тестовый режим
 *      зеленый     рабочий режим
 */

#ifndef INDICATOR_H_
#define INDICATOR_H_

// Состояния индикатора
typedef enum {
    IND_RED_ON      = 1<<0,
    IND_GREEN_ON    = 1<<1,
    IND_RED_OFF     = 1<<2,
    IND_GREEN_OFF   = 1<<3,
    IND_OFF         = IND_RED_OFF | IND_GREEN_OFF,
    IND_YELLOW_ON   = IND_RED_ON | IND_GREEN_ON
} ind_state_t;

// номера индикаторов
typedef enum { IND_CH1, IND_CH2, IND_CH3, IND_MODE, IND_NUM} ind_num_t;

/* Функция управления индикаторами
 * num      номер индикатора
 * state    добавление нового состояния индикатора
 */
void indControl(ind_num_t num, ind_state_t state);

/* Функция возвращает текущее состояние индикатора
 * num          номер индикатора
 *
 * результат    текущее состоние индикатора
 */
ind_state_t indCheck(ind_num_t num);

#endif /* INDICATOR_H_ */
