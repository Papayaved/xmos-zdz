#ifndef DEFINES_H_
#define DEFINES_H_
#include "ethernet.h"

/* [31:30] - type, [28:24] - ������, [23:16] - ��������� ������, [15:8] - ������ ������������, [7:0] - ��������� ������������
 * type
 *     A - ����� ������ (almost not tested)
 *     B - ����� ������ (almost tested)
 *     F - ������ ��� �������� �������� �� ���������������� ����������
 *     0 - ���������� ������ (factory)
 * ��������� ������ ������� � ��������� �� ������������� �����������
 */
#define SOFT_VER (0x81030000)

// ������ ��������� ��� ��������� ���������� ��
//#define SOFT_VER (0xC1030000)

// ������ ���������� � �������� �������� ������ ����� ��� �����
#define UCEIL(X) ( (unsigned)( (X) > (unsigned)(X) ? (X) + 1 : (X) ) )

// ������ ���������� ������������ �������� ���� �����
#define MIN(x, y) (((x) < (y)) ? (x) : (y))

// ������ ���������� ������������� �������� ���� �����
#define MAX(x, y) (((x) > (y)) ? (x) : (y))

// �������� ������ �� �����
#define CHECK_SWITCH(value, mask) (((value) & (mask)) == (mask))

// ��������� �������
#define TEN_NS  (1)
#define ONE_US  (100 * TEN_NS)
#define ONE_MS  (1000 * ONE_US)
#define ONE_S   (1000 * ONE_MS)

// ������������ ��������� �������� ���� �� �������
#define RELAY_HOLD (800 * ONE_MS)

// ������ ������� ���, �����
#define T_SMP (16 * 256)

// ������� ������� ���, ��
#define ADC_SAMPLE_RATE (100.0e6 / T_SMP) // 24414.0625 Hz

// ������ ��������� �������� ����������� � ������� � �������� ������, ���
#define LED_WORK_PERIOD_SEC (20.0)
#define LED_TEST_PERIOD_SEC (0.35)

/* ������ ��������� �������� ����������� � �������� ������� ��� (����� �����)
 * ����� ����� ������������ ��� ������������ ������������ ������ ����������� � ���
*/
#define LED_WORK_PERIOD_SMP ( UCEIL(LED_WORK_PERIOD_SEC * ADC_SAMPLE_RATE) )
#define LED_TEST_PERIOD_SMP ( UCEIL(LED_TEST_PERIOD_SEC * ADC_SAMPLE_RATE) )

// ������ ��������� ����������� ��� �������� � ��������� �������, � ������
#define LED_WORK_PERIOD ( LED_WORK_PERIOD_SMP * T_SMP ) // 2000003072
#define LED_TEST_PERIOD ( LED_TEST_PERIOD_SMP * T_SMP )

// ������������ �������� �������� ����������, � ������
#define TEST_DURATION (1 * T_SMP)

/* ���������� �������� ��� �� ����� ������� ������ ���� ������� �������� ������
 * ���� �� ���� ��������������� �������� ������ �� ��� ��������
 */
#define FAIL_RATE_WORK (3 * LED_WORK_PERIOD_SMP)
#define FAIL_RATE_TEST (3 * LED_TEST_PERIOD_SMP)

/* ������ ������� ������ WATCHDOG ������� � ���������� ������� ���
 * 1.0 ���
 */
#define WDT_PERIOD_SMP ( UCEIL(1.0 * ADC_SAMPLE_RATE) )

// ������ ������� ������ WATCHDOG ������� � ������
#define WDT_PERIOD (WDT_PERIOD_SMP * T_SMP)

// ����� ������������ �������
#define UP (150) // �������� ���������� ��������� ������ ��������
#define DUR (12) // ����������� ������������ ��������

// ����� ������������ ��������
#define SAT (60000)

// ������������ ������������ �������� ��� ������������
#define SATLEN (30)

// ����� ������ ��������������� �������� �������
#define LEN (20)

// ������������ ������ Ethernet ������ ������� CRC
#define MTU ETHERNET_MAX_PACKET_SIZE
#define ETHERNET_BUFSIZE (16 * MTU)
#define ETHERNET_SMI_PHY_ADDRESS (3)

// ������ ���
enum {CH_1, CH_2, CH_3, ADC_NUM};

// ����� ��������������
enum {SW3_TO_SW1 = 1<<0, SW_DELAY1 = 1<<1, SW_DELAY2 = 1<<2, SW2_TO_SW1 = 1<<3, SW2_OFF = 1<<4, SW3_OFF = 1<<5, SW_MODE = 1<<6};

/* ����� ������
 *      1 - ������� �����
 *      0 - �������� �����
 */
#define IS_WORK_MODE(value) (CHECK_SWITCH(value, SW_MODE))

// ����������� ����� ��
void soft_reset0();

#endif /* DEFINES_H_ */
