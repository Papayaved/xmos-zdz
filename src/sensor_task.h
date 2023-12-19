/* ������ �������� */

#ifndef SENSOR_H_
#define SENSOR_H_

#include "all_libs.h"
#include "defines.h"

#include "app_task.h"
#include "led_task.h"
#include "osc_task.h"

// ��������� ���������� ������
#define ADC_PRN

// �������� ������� �������
typedef enum {OFF, ON} SIGNAL;

typedef struct {
    int up;
    unsigned dur;
    int sat;
    unsigned sat_len;
} sens_param_t;

/* ������ ����������� ������ ��������� ��������� ������� ����� � ��������� �������� ��������
 * num      ����� ���������� ������
 * param    ��������� ����� ���������� ������ ��������
 * c_adc    ����� �� ������ ���
 * i_app    ��������� � ��������������� ����������
 * i_osc    ��������� � ������ ������������
 * i_led    ��������� � ������ ������������ �������� ��������
 */
void sensor_task(
    int num,
    const sens_param_t param,
    streaming chanend c_adc,
    client application_if i_app,
    client osc_if i_osc,
    client led_if i_led
);

#endif /* SENSOR_H_ */
