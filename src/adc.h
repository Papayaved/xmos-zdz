/* ��� ������� �����-������ ������������ sinc3 � ���������� � 256 ���
 * ��������� �������� �� ��������� 0 - 0xFFFF
 * ������� ��������� 100 MHz/16/256
 * ������� ���������� �� ������-����� ��������� 100 MHz/16 = 6.25 MHz
 */

#ifndef ADC_H_
#define ADC_H_

// �������� �����-������ �����������
void sinc3(in buffered port:32 ip, streaming chanend ce);

// ��������������� �����-������ ����������� ��� �������������� �������� �������
unsafe void sinc3m(in buffered port:32 ip, int* const unsafe control, int* const unsafe result);

#endif /* ADC_H_ */
