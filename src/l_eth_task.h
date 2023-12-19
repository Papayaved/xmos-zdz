/*
 * ��������� ������� � ���������� ������ eth_task
 */

#ifndef L_ETH_TASK_H_
#define L_ETH_TASK_H_

/* Local types */

// ��������� ��� �������� ������������ � ������������� ������� ���������� GOOSE ���������
typedef struct {
    uint32_t T_min;
    uint32_t T_max;
} Settings;

// ���� Ethernet ������� ��� ������� ���������
typedef enum {MY_MAC_INDEX, BROADCAST_MAC_INDEX} MAC_INDEX;

/* Local variables */

extern uint64_t my_mac; // MAC ����� ����������
extern sens_param_t l_param;

extern uint64_t remote_mac; // MAC ����� ���������� ����������
extern uint32_t my_ip; // IP ����� ����������
extern uint32_t remote_ip; // IP ����� ���������� ����������
extern uint16_t my_port; // UDP ���� ����������
extern uint16_t remote_port; // UDP ���� ���������� ����������
extern BOOL goose_ena; // ������ GOOSE ��������� ��������
extern BOOL goose_req; // ���� ������� ��������� ���������� GOOSE
extern BOOL arp_req; // ������ ��������� ARP
extern BOOL soft_rst_req; // ������ ����������� ������ ���������� GOOSE

extern Settings set; // ��������� GOOSE
extern OscSettings osc_set; // c�������� � ����������� ������ �����������

/* Local functions */

/* ���������� ������� ������ ������� ���������� ������ �� Flash ������
 * print_ena    ���./����. ������ �������������� ���������� ����������
 */
void GooseInit0(BOOL print_ena);

/* ���������� ������� ��������� ���������� ������ ���������� �� �������� �� ���������
 * � ������, ���� ������ Flash ������ ��������� �� �������
 * fabric_ena   ������������ ��������� ��������� �� ���������
 * goose_ena    ������������ ������ GOOSE �� ���������
 * set_ena      ������������ ��������� GOOSE �� ���������
 */
void SetDefault(BOOL fabric_ena, BOOL goose_ena, BOOL set_ena);

#endif /* L_ETH_TASK_H_ */
