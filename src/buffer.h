/* ������ ����� � �������� ethernet ������� � ������� ������ � ����
 * �������� ���������� �� ������ � xC ��������� �� �������
 */

#ifndef BUFFER_H_
#define BUFFER_H_

#include "defines.h"
#include "goose.h"

extern GoosePacket rx_goose; // ���� ����� ������ ���� � ����� GOOSE ������
extern uint8_t tx_buf[MTU]; // ����� �� ��������

// �������� �����

// ��������� ���������� ������ ������ ������ �� �������� ������ (����� �����)
void init_rx_buf(unsigned rx_start_pos);

// ������� ������ 64, 32, 8 ��������� ������ �� ��������� ������, ���������� ��������� ������������ �� ��������� ������
uint64_t read_uint64();
uint32_t read_uint32();
uint8_t read_uint8();

/* ������ ������� ������ �� ��������� ������, ���������� ��������� ������������ �� ��������� ������
 * data     ������ ���� ������������ ������
 * n        ���������� ����������� ������
 *
 * ���������
 * TRUE     ������ ������ �������
 * FALSE    ������
 */
BOOL read_range(uint8_t data[n], unsigned n);

// ���������� �����

// ��������� ���������� ������ ������ ������ � ���������� ����� (����� �����)
void init_tx_buf(unsigned tx_start_pos);

// �������� ������� ������� ������ �� �������� ������. ����� ����� ������� � ������
int get_tx_pos();

// �������� � ����� �������� 32� ��� 8 ��������� ������. ��������� ������������ �� ��������� ������
void add_uint32(uint32_t data);
void add_uint8(int8_t data);

/* ������ ������� ������ � ���������� �����
 * data     ������ ������
 * n        ���������� ������������ ������
 */
void add_range(const uint8_t data[n], unsigned n);

// �������� ��������� �� ������ � ������� �������
const uint8_t* alias get_read_ptr();

// ������� ������ 48, 32, 16 ��������� ������ � ����������� ������� ����
uint64_t byterev48(const uint8_t* const p_begin);
uint32_t byterev32(const uint8_t* const p_begin);
uint16_t byterev16(const uint8_t* const p_begin);

/* ������� ������ 48, 32, 16 ��������� ������ � ����������� ������� ����
 * p_begin  ��������� �� ��������� �����
 * value    ������������ ��������
 * */
void write_byterev48(uint8_t* const p_begin, uint64_t value);
void write_byterev32(uint8_t* const p_begin, uint32_t value);
void write_byterev16(uint8_t* const p_begin, uint16_t value);

/* ������� ������ 64 ���������� ����� �� �� ����������� ������
 * p_begin  ��������� �� ��������� �����
 * value    ������������ ��������
 * */
void write64(uint8_t* const p_begin, uint64_t& value);

#endif /* BUFFER_H_ */
