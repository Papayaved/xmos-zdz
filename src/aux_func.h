/* ��������������� �������  */

#ifndef AUX_FUNC_H_
#define AUX_FUNC_H_
#include "all_libs.h"

/* ���������� � ������� ������� ���� */
void PrintByteArray(const uint8_t ar[n], unsigned n);

/* ������� ������� CRC16 ��� ModRTU
 * ptr  ��������� �� ������ ������
 * len  ������ ������
 * */
uint16_t ModRTU_CRC(const uint8_t* const ptr, int len);

#endif /* AUX_FUNC_H_ */
