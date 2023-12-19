/* ������ ����������� ���������
 * ��������� ��������� ����������� (1, 2, 3):
 *      ����         ����� ��������, ������������ �� ����
 *      �������      �����
 *      ��������     ���� ������������
 *      ������       ����� � ���� ������������ (�� ������� ���������)
 *
 * ��������� ���������� ������ ������ (4):
 *      ����        ��� �������
 *      �������     �������� �����
 *      �������     ������� �����
 */

#ifndef INDICATOR_H_
#define INDICATOR_H_

// ��������� ����������
typedef enum {
    IND_RED_ON      = 1<<0,
    IND_GREEN_ON    = 1<<1,
    IND_RED_OFF     = 1<<2,
    IND_GREEN_OFF   = 1<<3,
    IND_OFF         = IND_RED_OFF | IND_GREEN_OFF,
    IND_YELLOW_ON   = IND_RED_ON | IND_GREEN_ON
} ind_state_t;

// ������ �����������
typedef enum { IND_CH1, IND_CH2, IND_CH3, IND_MODE, IND_NUM} ind_num_t;

/* ������� ���������� ������������
 * num      ����� ����������
 * state    ���������� ������ ��������� ����������
 */
void indControl(ind_num_t num, ind_state_t state);

/* ������� ���������� ������� ��������� ����������
 * num          ����� ����������
 *
 * ���������    ������� �������� ����������
 */
ind_state_t indCheck(ind_num_t num);

#endif /* INDICATOR_H_ */
