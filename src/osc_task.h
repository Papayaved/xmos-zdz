/* Задача записи осцилограмм данных с АЦП */

#ifndef OSC_TASK_XC_H_
#define OSC_TASK_XC_H_

#include "all_libs.h"
#include "my_types.h"
#include "defines.h"

// печать осцилограмм в консоль, вместо отправки по Ethernet
//#define PRINT_OSC

#ifdef PRINT_OSC
    #define BUF_MASK (0x3F) // 64
#else
    #define BUF_MASK (0xFF) // маска адреса буфера
#endif

#define BUF_SIZE (BUF_MASK + 1) // размер буфера в 32х битных словах
#define OSC_SIZE (BUF_SIZE * sizeof(int)) // размер буфера одной осцилограммы в байтах

// Структура настроек режима работы осцилографа
typedef struct {
    uint8_t trig_ff; // битовые флаги по которым срабатывает триггер начала записи
    uint16_t startPos; // сдвиг данных
} OscSettings;

/* Интерфейс АЦП - осцилограф */
typedef interface osc_if {
    // Добавление данных в конец буфера FIFO
    void Add(int adc);

    // Срабатывание датчика
    void Trigger();
} osc_if;

/* Интерфейс задачи осцилографа с задачей отправки данных по Ethernet */
typedef interface osc_eth_if{
    // оповещение о готовности осцилограмм
    [[notification]] slave void osc_ready();

    /* запись осцилограммы в Ethernet пакет
     * osc_num      номер осциллографа (1,2,3)
     * pos          начальная позиция в буфере
     * packet[]     внешний буфер данных для записи
     * n            размер буфера
     */
    [[clears_notification]] void get_data(unsigned osc_num, unsigned pos, uint8_t packet[n], unsigned n);

    /* запуск/отключение осциллографа
     * set  структура с параметрами работы осциллографа
     */
    void run(const OscSettings& set);
} osc_eth_if;

/* Задача осциллографа
 * i_osc        интерфейс записи данных со стороны АЦП
 * i_osc_eth    интерфейс отправки данных в сеть
 */
//[[combinable]]
[[distributable]]
 void OscTask(
         server osc_if i_osc[n], unsigned n,
         server osc_eth_if i_osc_eth);

#endif /* OSC_TASK_XC_H_ */
