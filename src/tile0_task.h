/* ������ ������� � ������ ���������� */

#ifndef TILE0_TASK_H_
#define TILE0_TASK_H_

#include "my_types.h"
#include "defines.h"
#include "relay.h"
#include "indicator.h"

// ����� watchdog �������
void wdt_reset0();

/* ������ DIP �������������
 * ���������    ��� ������������ �� ������������� ������� ������
 */
uint8_t GetSwitches0();

/* ��������� � ������ �������������� ������ � ����� ���������� */
typedef interface tile0_resources_if {
    /* ���������� ����
     * mask     ����� ����
     * state    �������� ���������
     * */
    void relayControlMask(RELAY_MASK_T mask, BOOL state);

    /* ���������� ������������
     * num      ����� ����������
     * state    �������� ���������
     * */
    void indControl(ind_num_t num, ind_state_t state);

    /* ������ ��������� �����������
     * num          ����� ����������
     * ���������    ������� ���������
     * */
    ind_state_t indCheck(ind_num_t num);

    // ����� watchdog �������
    void wdtReset();

    // ���������� �� ���������� ������ ������
    [[notification]] slave void Update();

    // ������ ���� ������������� �� DIP ��������������
    [[clears_notification]] uint8_t getSwitches();
} tile0_resources_if;

// ��������� ������ ������ ������ ������������� �� DIP ��������������
typedef interface tile0_switches_if {
    // ���������� �� ��������� ���������
    [[notification]] slave void Update();

    // ������� ��������� DIP ��������������
    [[clears_notification]] uint8_t getSwitches();
} tile0_switches_if;

/* ������ �������������� ������ � ��������� ����������
 * i_t0     ������ ��������� ������� � ������
 * i_sw     ������ ��������� ������� � ������
 */
[[combinable]]
void tile0_task(server tile0_resources_if i_t0, server tile0_switches_if i_sw[2]);

// ������� ������������� �������
void InitChannels0();

#endif /* TILE0_TASK_H_ */
