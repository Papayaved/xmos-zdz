#ifndef ETH_TSK_H_
#define ETH_TSK_H_

#include <stdio.h>
#include <xs1.h>
#include <timer.h>

#include <ethernet.h>
#include <mii.h>
#include <smi.h>

#include <string.h>
#include <print.h>
#include <trycatch.h>
#include <debug_print.h>

#include "clock_task.h"
#include "mdio.h"

#include "goose.h"
#include "tile0_task.h"
#include "osc_task.h"

#include "flash.h"

//#define ETH_DEBUG // ������� Ethernet

#define DEFAULT_MY_PORT (60000) // UDP ���� ����� ������ � ���� ��������� ������ ����������
#define DEFAULT_REMOTE_PORT (60001) // UDP ���� ���������� ������ (�������� ���� ��)

/* ������ ������������� ����� � �������� ������ �� ����
 * ������ ���� �������� �� tile0 ��������� �������� � flash ������� ���������������� ��������
 * factory      MAC �����, ������ � �������� �����
 * param        ��������� ������ �������
 * i_cfg        ��������� ���������������� Ethernet �����������
 * i_rx         ��������� ����� ������
 * i_tx         ��������� �������� ������
 * i_smi        ��������� � ����������� ����������� ������ Ethernet
 * i_clock      ��������� � ������� �������� clock_task
 * i_g          ��������� � ������� main_task
 * i_sw         ��������� ������ ��������� DIP ��������������
 * i_osc_eth    ��������� � ������� �����������
 */
//[[combinable]]
void eth_task0(
    const factory_t& factory,
    const sens_param_t& param,
    client ethernet_cfg_if i_cfg,
    client ethernet_rx_if i_rx,
    client ethernet_tx_if i_tx,
    client smi_if i_smi,
    client clock_if i_clock,
    client goose_if i_g,
    client tile0_switches_if i_sw,
    client osc_eth_if i_osc_eth
);

#endif /* ETH_TSK_H_ */
