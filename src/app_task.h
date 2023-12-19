// ������ ����������� �������� ������ ������ ����������

#ifndef APP_TASK_H_
#define APP_TASK_H_

#include "tile0_task.h"
#include "goose.h"

/* ��������� �������� � �������� ���������� */
typedef interface application_if {
    /* ���������� ��������������� �������� �������� */
    void reportTest(unsigned testDetected);

    /* ������������� ������������ */
    void reportAlarm(unsigned alarmType);

    /* ����� ������������ */
    void reportAlarmOff(void);
} application_if;

/* �������� ��������� ������ ���
 * application_if       ��������� � ���������
 * tile0_resources_if   ��������� � ������� �����-������
 * goose_if             ��������� c ������� ������� ��� �������� �������������� ��������� GOOSE
 */
// todo: ���������� ���� �� ������������� ������ � ������� � �������� ���������, �� ��� �������� �������� �������� �� ���������� ��������
void app_task(
    server application_if i_app[n], unsigned n,
    client tile0_resources_if i_t0,
    server goose_if i_g);

#endif /* ZDZ_MAIN_H_ */
