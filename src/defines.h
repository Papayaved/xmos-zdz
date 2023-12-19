#ifndef DEFINES_H_
#define DEFINES_H_
#include "ethernet.h"

/* [31:30] - type, [28:24] - версия, [23:16] - подверсия версия, [15:8] - версия разработчика, [7:0] - подверсия разработчика
 * type
 *     A - альфа версия (almost not tested)
 *     B - бетта версия (almost tested)
 *     F - версия для тестовой загрузки по технологическому интерфейсу
 *     0 - стабильная версия (factory)
 * Изменение версии говорит о частичной не совместимости интерфейсов
 */
#define SOFT_VER (0x81030000)

// версия программы для тестового обновления ПО
//#define SOFT_VER (0xC1030000)

// Макрос округления к большему значению целому числа без знака
#define UCEIL(X) ( (unsigned)( (X) > (unsigned)(X) ? (X) + 1 : (X) ) )

// Макрос вычисления минимального значения двух чисел
#define MIN(x, y) (((x) < (y)) ? (x) : (y))

// Макрос вычисления максимального значения двух чисел
#define MAX(x, y) (((x) > (y)) ? (x) : (y))

// Проверка данных по маске
#define CHECK_SWITCH(value, mask) (((value) & (mask)) == (mask))

// Константы времени
#define TEN_NS  (1)
#define ONE_US  (100 * TEN_NS)
#define ONE_MS  (1000 * ONE_US)
#define ONE_S   (1000 * ONE_MS)

// Длительность удержания выходных реле по каналам
#define RELAY_HOLD (800 * ONE_MS)

// Период выборок АЦП, такты
#define T_SMP (16 * 256)

// Частота выборок АЦП, Гц
#define ADC_SAMPLE_RATE (100.0e6 / T_SMP) // 24414.0625 Hz

// Период импульсов тестовых светодиодов в рабочем и тестовом режиме, сек
#define LED_WORK_PERIOD_SEC (20.0)
#define LED_TEST_PERIOD_SEC (0.35)

/* Период импульсов тестовых светодиодов в периодах выборок АЦП (целое число)
 * Целое число используется для максимальной синхронности работы светодиодов и АЦП
*/
#define LED_WORK_PERIOD_SMP ( UCEIL(LED_WORK_PERIOD_SEC * ADC_SAMPLE_RATE) )
#define LED_TEST_PERIOD_SMP ( UCEIL(LED_TEST_PERIOD_SEC * ADC_SAMPLE_RATE) )

// Период импульсов светодиодов для рабочего и тестового режимов, в тактах
#define LED_WORK_PERIOD ( LED_WORK_PERIOD_SMP * T_SMP ) // 2000003072
#define LED_TEST_PERIOD ( LED_TEST_PERIOD_SMP * T_SMP )

// Длительность импульса тестовых светодидов, в тактах
#define TEST_DURATION (1 * T_SMP)

/* Количество отсчетов АЦП за время которых должен быть получен тестовый сигнал
 * Хотя бы один детектированный тестовый сигнал за три импульса
 */
#define FAIL_RATE_WORK (3 * LED_WORK_PERIOD_SMP)
#define FAIL_RATE_TEST (3 * LED_TEST_PERIOD_SMP)

/* Период сигнала сброса WATCHDOG таймера в количестве отчетов АЦП
 * 1.0 сек
 */
#define WDT_PERIOD_SMP ( UCEIL(1.0 * ADC_SAMPLE_RATE) )

// Период сигнала сброса WATCHDOG таймера в тактах
#define WDT_PERIOD (WDT_PERIOD_SMP * T_SMP)

// Порог срабатывания датчика
#define UP (150) // скорость нарастания переднего фронта импульса
#define DUR (12) // минимальная длительность импульса

// Порог максимальной засветки
#define SAT (60000)

// Длительность максимальной засветки для срабатывания
#define SATLEN (30)

// длина буфера предварительной проверки каналов
#define LEN (20)

// Максимальный размер Ethernet пакета включая CRC
#define MTU ETHERNET_MAX_PACKET_SIZE
#define ETHERNET_BUFSIZE (16 * MTU)
#define ETHERNET_SMI_PHY_ADDRESS (3)

// Номера АЦП
enum {CH_1, CH_2, CH_3, ADC_NUM};

// Маски переключателей
enum {SW3_TO_SW1 = 1<<0, SW_DELAY1 = 1<<1, SW_DELAY2 = 1<<2, SW2_TO_SW1 = 1<<3, SW2_OFF = 1<<4, SW3_OFF = 1<<5, SW_MODE = 1<<6};

/* Режим работы
 *      1 - рабочий режим
 *      0 - тестовый режим
 */
#define IS_WORK_MODE(value) (CHECK_SWITCH(value, SW_MODE))

// Программный сброс мк
void soft_reset0();

#endif /* DEFINES_H_ */
