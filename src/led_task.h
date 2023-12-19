/* ������ ������������ ��������� �������� ��������� */

#ifndef LED_TASK_H_
#define LED_TASK_H_

#include "my_types.h"
#include "defines.h"
#include "tile0_task.h"

// ��������� ��������� ����������
typedef enum {TEST_LED_OFF, TEST_LED_ON} TEST_LED;

// ��������� � ������� ���������� ��������� ������������
typedef interface led_if {
    // ������ ������������ ��������� �������
    unsigned TestPeriod();

    // ������ ������
    [[notification]] slave void Req(void);

    /* ������ ��������� ��������� ����������
     * TRUE     �������
     * FALSE    ��������
     */
    [[clears_notification]] BOOL isLed();
} led_if;

/* ������ ������������ �������� �������� ���������
 * i_led    ��������� � ��������
 * i_sw     ��������� � DIP ������������ ��������� ����� ������
 * */
void led_task0(server led_if i_led[ADC_NUM], client tile0_switches_if i_sw);

/* ������� ���������� ��������� ������������
 * workMode     ����� ������
 * onoff        ��������� ����������
 */
void TestLedControl(BOOL workMode, TEST_LED onoff);

#endif /* LED_TASK_H_ */
