/* ������ � ������� ������� ������� Ethernet
 * goose_tmr    ������ GOOSE ���������
 * clock_tmr    ������ ��������� �������� �������������� �������
 * link_tmr     ������ ������ ��������� Ethernet
 */

#ifndef TIME_TASK_H_
#define TIME_TASK_H_
#include "all_libs.h"
#include "my_types.h"

/* ������ ������ ��������� ����� ����� �� ����� ������ Ethernet ����������
 * ��� �������������� ����� ������ ��������, �������� ��������� ���� ������ � ��������� GOOSE ���������
 */
#define LINK_T (250 * ONE_MS)

// ���� ������� ������
typedef enum {NO_ALARM = 0, CLOCK_ALARM = 1<<0, GOOSE_ALARM = 1<<1, LINK_ALARM = 1<<2} AlarmFlags;

// ��������� � ������ clock_task
typedef interface clock_if{
    /* ���/���� ������� �������� ����� ����� */
    void LinkEna(BOOL enable);

    /* ���������� ������ ��������� � ������� ������ ������� */
    uint32_t getSeconds();

    // ���������� � ������������ ������ ��� ���������� ��������
    [[notification]] slave void Alarm();

    // ������ ���� ������������ �������, ����� ����������
    [[clears_notification]] AlarmFlags AlarmType();

    /* ��������� ������� GOOSE ��������� � ��������� ������ �������, � ��
     * ������ ����������� ������������� ����� ������� ������������,
     * ��� ������ ��� �������� ���������
     * ����� ���������� ���������� ���� ��������!
     */
    [[clears_notification]] void setGooseAlarm(unsigned msec);
} clock_if;

/* ������ �������� */
//[[combinable]]
 void clock_task(server clock_if i_clock);

#endif /* TIME_TASK_H_ */
