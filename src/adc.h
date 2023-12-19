/* Две функции сигма-дельта демодулятора sinc3 с децимацией в 256 раз
 * Результат округлен до диапазона 0 - 0xFFFF
 * Частота измерений 100 MHz/16/256
 * Частота подающаяся на дельта-сигма модулятор 100 MHz/16 = 6.25 MHz
 */

#ifndef ADC_H_
#define ADC_H_

// Основной сигма-дельта демодулятор
void sinc3(in buffered port:32 ip, streaming chanend ce);

// Вспомогательный сигма-дельта демодулятор для первоначальной проверки каналов
unsafe void sinc3m(in buffered port:32 ip, int* const unsafe control, int* const unsafe result);

#endif /* ADC_H_ */
