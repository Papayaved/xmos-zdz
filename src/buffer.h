/* Буфера приёма и передачи ethernet пакетов и функции работы с ними
 * Передача указателей на буфера в xC оказалась не удобной
 */

#ifndef BUFFER_H_
#define BUFFER_H_

#include "defines.h"
#include "goose.h"

extern GoosePacket rx_goose; // приём любых данных идет в буфер GOOSE пакета
extern uint8_t tx_buf[MTU]; // буфер на передачу

// ПРИЕМНЫЙ БУФЕР

// установка начального адреса чтения данных из приёмного буфера (номер байта)
void init_rx_buf(unsigned rx_start_pos);

// функции чтения 64, 32, 8 разрядных данных из приемного буфера, внутренний указатель перемещается на следующие данные
uint64_t read_uint64();
uint32_t read_uint32();
uint8_t read_uint8();

/* Чтение массива данных из приемного буфера, внутренний указатель перемещается на следующие данные
 * data     массив куда записываются данные
 * n        количество считываемых данных
 *
 * результат
 * TRUE     чтение прошло успешно
 * FALSE    ошибка
 */
BOOL read_range(uint8_t data[n], unsigned n);

// ПЕРЕДАЮЩИЙ БУФЕР

// установка начального адреса записи данных в передающий буфер (номер байта)
void init_tx_buf(unsigned tx_start_pos);

// получить текущую позицию буфера на передачу данных. Номер байта готовый к записи
int get_tx_pos();

// добавить в буфер передачи 32х или 8 разрядные данные. Указатель перемещается на следующие данные
void add_uint32(uint32_t data);
void add_uint8(int8_t data);

/* Запись массива данных в передающий буфер
 * data     массив данных
 * n        количество записываемых данных
 */
void add_range(const uint8_t data[n], unsigned n);

// получить указатель на чтение с текущей позиции
const uint8_t* alias get_read_ptr();

// Функции чтения 48, 32, 16 разрядных данных в реверсивном порядке байт
uint64_t byterev48(const uint8_t* const p_begin);
uint32_t byterev32(const uint8_t* const p_begin);
uint16_t byterev16(const uint8_t* const p_begin);

/* Функции записи 48, 32, 16 разрядных данных в реверсивном порядке байт
 * p_begin  указатель на начальный адрес
 * value    записываемое значение
 * */
void write_byterev48(uint8_t* const p_begin, uint64_t value);
void write_byterev32(uint8_t* const p_begin, uint32_t value);
void write_byterev16(uint8_t* const p_begin, uint16_t value);

/* функция записи 64 разрядного числа по не выровненому адресу
 * p_begin  указатель на начальный адрес
 * value    записываемое значение
 * */
void write64(uint8_t* const p_begin, uint64_t& value);

#endif /* BUFFER_H_ */
