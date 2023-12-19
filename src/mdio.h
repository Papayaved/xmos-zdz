#ifndef MDIO_H_
#define MDIO_H_
#include <smi.h>
#include "my_types.h"

/* ������� �������� ����������� Ethernet ������
 * i_smi    ��������� � ����������� ����������� ������ Ethernet
 *
 * ������������ ��������:
 * TRUE     ������ �����������
 * FALSE    ��� ������
 */
BOOL isPhyLink(client smi_if i_smi);

/* ������� �������� ������� ���������� ����������� ������ Ethernet
 * i_smi    ��������� � ����������� ����������� ������
 *
 * ������������ ��������:
 * TRUE     ���������� �������
 * FALSE    ��� ����������
 */
BOOL TestMDIO(client smi_if i_smi);

#endif /* MDIO_H_ */
