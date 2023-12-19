/* ������ ������ ����������� ������ � ��� */

#ifndef OSC_TASK_XC_H_
#define OSC_TASK_XC_H_

#include "all_libs.h"
#include "my_types.h"
#include "defines.h"

// ������ ����������� � �������, ������ �������� �� Ethernet
//#define PRINT_OSC

#ifdef PRINT_OSC
    #define BUF_MASK (0x3F) // 64
#else
    #define BUF_MASK (0xFF) // ����� ������ ������
#endif

#define BUF_SIZE (BUF_MASK + 1) // ������ ������ � 32� ������ ������
#define OSC_SIZE (BUF_SIZE * sizeof(int)) // ������ ������ ����� ������������ � ������

// ��������� �������� ������ ������ �����������
typedef struct {
    uint8_t trig_ff; // ������� ����� �� ������� ����������� ������� ������ ������
    uint16_t startPos; // ����� ������
} OscSettings;

/* ��������� ��� - ���������� */
typedef interface osc_if {
    // ���������� ������ � ����� ������ FIFO
    void Add(int adc);

    // ������������ �������
    void Trigger();
} osc_if;

/* ��������� ������ ����������� � ������� �������� ������ �� Ethernet */
typedef interface osc_eth_if{
    // ���������� � ���������� �����������
    [[notification]] slave void osc_ready();

    /* ������ ������������ � Ethernet �����
     * osc_num      ����� ������������ (1,2,3)
     * pos          ��������� ������� � ������
     * packet[]     ������� ����� ������ ��� ������
     * n            ������ ������
     */
    [[clears_notification]] void get_data(unsigned osc_num, unsigned pos, uint8_t packet[n], unsigned n);

    /* ������/���������� ������������
     * set  ��������� � ����������� ������ ������������
     */
    void run(const OscSettings& set);
} osc_eth_if;

/* ������ ������������
 * i_osc        ��������� ������ ������ �� ������� ���
 * i_osc_eth    ��������� �������� ������ � ����
 */
//[[combinable]]
[[distributable]]
 void OscTask(
         server osc_if i_osc[n], unsigned n,
         server osc_eth_if i_osc_eth);

#endif /* OSC_TASK_XC_H_ */
