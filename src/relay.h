/* ������ ���������� ���� */

#ifndef RELAY_H_
#define RELAY_H_
#include "my_types.h"

// ������ ����
//enum {RELAY_CH1_1 = 0, RELAY_CH1_2 = 1, RELAY_CH2 = 2, RELAY_CH3 = 3, RELAY_ALARM = 4, RELAY_OTKAZ = 5, RELAY_NUM};
#define RELAY_NUM (6)

typedef enum {
    RELAY_MSK_CH1_1 = 1<<0,
    RELAY_MSK_CH1_2 = 1<<1,
    RELAY_MSK_CH1   = RELAY_MSK_CH1_1 | RELAY_MSK_CH1_2,
    RELAY_MSK_CH2   = 1<<2,
    RELAY_MSK_CH3   = 1<<3,
    RELAY_MSK_ALARM = 1<<4,
    RELAY_MSK_OTKAZ = 1<<5
} RELAY_MASK_T;

#define RELAY_DEFAULT (0)

/* ���./����. ������ ���� �������� ������
 * mask     ����� ������ ����
 * enable   �������� ��������� (0, 1)
 */
void relayControlMask(RELAY_MASK_T mask, BOOL enable);

/* ������������ ���������� ����
 * num      ����� ����
 * enable   �������� ��������� (0, 1)
 */
//void relayControl(unsigned num, BOOL enable);

#endif /* RELAY_H_ */
