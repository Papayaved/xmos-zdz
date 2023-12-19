/* ���������� ������ ������������ � ��
 * ����� ������ eth_task
 */

#ifndef RX_CONT_H_
#define RX_CONT_H_
#include "all_libs.h"
#include "my_types.h"
#include "defines.h"

#include "flash.h"
#include "tile0_task.h"
#include "osc_task.h"

#define ETH_HEADER_LEN (14) // sizeof(DstMac) + sizeof(SrcMac) + sizeof(EtherType) - ������ ��������� Ethernet
#define IP_HEADER_LEN (12) // ������ IP ���������
#define UDP_HEADER_LEN (8) // ������ UDP ���������
#define FULL_HEADER_LEN (ETH_HEADER_LEN + IP_HEADER_LEN + UDP_HEADER_LEN) // ����� ������ ���������

#define MAC_BROADCAST (0xFFFFFFFFFFFFULL) // ����������������� Ethernet �����
#define IP_BROADCAST (0xFFFFFFFFU) // ����������������� IP �����

// ���� ����� Ethernet �������
typedef enum {
    ETHERTYPE_IP        = (uint16_t)0x0800,
    ETHERTYPE_ARP       = (uint16_t)0x0806,
    ETHERTYPE_VLAN      = (uint16_t)0x8100,
    ETHERTYPE_GOOSE     = (uint16_t)0x88b8,
    ETHERTYPE_UNKNOWN   = (uint16_t)0
} ETHERTYPE;

// ���� ����� ARP �������
typedef enum {ARP_REQUEST = (uint16_t)1, ARP_REPLY = (uint16_t)2} ARP_OPER;

// ���� ����� IP �������
typedef enum {IP_UDP = (uint8_t)0x11, IP_PROTOCOL_UNKNOWN} IP_PROTOCOL;

// ���� �������������� Ethernet �������
typedef enum {UDP_PACKET, GOOSE_PACKET} PacketType;

/* �������� ������� ��������� �������� ��������� � ������������ �������
 * rx_info      ��������� � ����������� � �������� Ethernet ������
 * i_tx         ��������� ����������� Ethernet ��� �������� �������
 * i_sw         ��������� ������ ��������� DIP ��������������
 * i_osc_eth    ��������� ���������� ������� �����������
 * */
void rx_controller(
        const ethernet_packet_info_t rx_info,
        client ethernet_tx_if i_tx,
        client tile0_switches_if i_sw,
        client osc_eth_if i_osc_eth);

/* ������� ������ Ethernet ����� ���������
 * eth_pack[]   Ethernet �����
 * */
uint64_t DstMac(const uint8_t eth_pack[MTU]);

/* ������� ������ Ethernet ����� ���������
 * eth_pack[]   Ethernet �����
 * */
uint64_t SrcMac(const uint8_t eth_pack[MTU]);

/* ������� ������ ��� Ethernet ������
 * eth_pack[]   Ethernet �����
 * */
uint16_t EthType(const uint8_t eth_pack[MTU]);

/* ������� ������ ������ IP ���������
 * eth_pack[]   Ethernet �����
 * */
uint8_t IPVer(const uint8_t eth_pack[MTU]);

/* ������� ������ ����� ��������� IP ������
 * eth_pack[]   Ethernet �����
 * */
uint8_t IPHeaderLen(const uint8_t eth_pack[MTU]);

/* ������� ������ ���� TotalLen IP ������
 * eth_pack[]   Ethernet �����
 * */
uint16_t TotalLen(const uint8_t eth_pack[MTU]);

/* ������� ������ ���������� ������������� IP ������
 * eth_pack[]   Ethernet �����
 * */
uint16_t ID(const uint8_t eth_pack[MTU]);

/* ������� ������ ��� ���������� � IP ����� ���������
 * eth_pack[]   Ethernet �����
 * */
uint8_t Protocol(const uint8_t eth_pack[MTU]);

/* ������� ������ ���� ����������� ����� IP ������
 * eth_pack[]   Ethernet �����
 * */
uint16_t HChecksum(const uint8_t eth_pack[MTU]);

/* ������� ������ IP ����� ���������
 * eth_pack[]   Ethernet �����
 * */
uint32_t SrcIP(const uint8_t eth_pack[MTU]);

/* ������� ������ IP ����� ���������
 * eth_pack[]   Ethernet �����
 * */
uint32_t DstIP(const uint8_t eth_pack[MTU]);

/* ������� ������ UDP ���� ���������
 * eth_pack[]   Ethernet �����
 * */
uint16_t SrcPort(const uint8_t eth_pack[MTU]);

/* ������� ������ UDP ���� ���������
 * eth_pack[]   Ethernet �����
 * */
uint16_t DstPort(const uint8_t eth_pack[MTU]);

/* ������� ������ ������ ������ � UDP ������
 * eth_pack[]   Ethernet �����
 * */
uint16_t Length(const uint8_t eth_pack[MTU]);

/* ������� ������ ����������� ����� UDP ������
 * eth_pack[]   Ethernet �����
 * */
uint16_t Checksum(const uint8_t eth_pack[MTU]);

//const uint8_t* alias UdpData(const uint8_t eth_pack[MTU]) { return &eth_pack[42]; }

/* ������� ������������������ ARP �������
 * i_tx     ��������� ������� ������
 * my_mac   Ethernet ����� ����������
 * TPA      ��������� IP �����
 * */
void SendARPReq(client ethernet_tx_if i_tx, uint64_t my_mac, uint32_t TPA);

/* ������� ������������� ARP �������, ����� ��������� Ethernet ����� ��� �������� (���������� ������� �������)
 * i_tx     ��������� ������� ������
 * */
void SendARPReq2(client ethernet_tx_if i_tx);

/* ������� ���������� � ������� IP ������
 * i_tx     ��������� ������� ������
 * my_mac   Ethernet ����� ����������
 */
void SendARPAnnounce(client ethernet_tx_if i_tx, uint64_t my_mac);

/* ������� ������ �� ARP ������
 * i_tx     ��������� ������� ������
 * THA      ������� (���������) Ethernet �����
 * my_mac   Ethernet ����� ����������
 * TPA      ������� (���������) IP �����
 */
void SendARPReply(client ethernet_tx_if i_tx, uint64_t THA, uint64_t my_mac, uint32_t TPA);

/* ������� ��������� UDP ������
 * i_tx     ��������� ������� ������
 * data     ���������� � UDP ������ ��������
 */
void TestUdp(client ethernet_tx_if i_tx, uint32_t data);

#endif /* RX_CONT_H_ */
