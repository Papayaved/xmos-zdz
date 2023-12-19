/* Вспомогательные функции  */

#ifndef AUX_FUNC_H_
#define AUX_FUNC_H_
#include "all_libs.h"

/* Распечатка к консоль массива байт */
void PrintByteArray(const uint8_t ar[n], unsigned n);

/* Функция расчета CRC16 для ModRTU
 * ptr  указатель на начало данных
 * len  размер данных
 * */
uint16_t ModRTU_CRC(const uint8_t* const ptr, int len);

#endif /* AUX_FUNC_H_ */
