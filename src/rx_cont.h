/* Внутренний модуль коммуникации с ПК
 * Часть задачи eth_task
 */

#ifndef RX_CONT_H_
#define RX_CONT_H_
#include "all_libs.h"
#include "my_types.h"
#include "defines.h"

#include "flash.h"
#include "tile0_task.h"
#include "osc_task.h"

#define ETH_HEADER_LEN (14) // sizeof(DstMac) + sizeof(SrcMac) + sizeof(EtherType) - размер заголовка Ethernet
#define IP_HEADER_LEN (12) // размер IP заголовка
#define UDP_HEADER_LEN (8) // размер UDP заголовка
#define FULL_HEADER_LEN (ETH_HEADER_LEN + IP_HEADER_LEN + UDP_HEADER_LEN) // общий размер заголовка

#define MAC_BROADCAST (0xFFFFFFFFFFFFULL) // широковещательный Ethernet адрес
#define IP_BROADCAST (0xFFFFFFFFU) // широковещательный IP адрес

// коды типов Ethernet пакетов
typedef enum {
    ETHERTYPE_IP        = (uint16_t)0x0800,
    ETHERTYPE_ARP       = (uint16_t)0x0806,
    ETHERTYPE_VLAN      = (uint16_t)0x8100,
    ETHERTYPE_GOOSE     = (uint16_t)0x88b8,
    ETHERTYPE_UNKNOWN   = (uint16_t)0
} ETHERTYPE;

// коды типов ARP пакетов
typedef enum {ARP_REQUEST = (uint16_t)1, ARP_REPLY = (uint16_t)2} ARP_OPER;

// кода типов IP пакетов
typedef enum {IP_UDP = (uint8_t)0x11, IP_PROTOCOL_UNKNOWN} IP_PROTOCOL;

// Типы поддерживаемых Ethernet пакетов
typedef enum {UDP_PACKET, GOOSE_PACKET} PacketType;

/* Основная функция обработки входящих сообщений и формирования ответов
 * rx_info      структура с информацией о принятом Ethernet пакете
 * i_tx         интерфейс контроллера Ethernet для передачи пакетов
 * i_sw         интерфейс чтения состояния DIP переключателей
 * i_osc_eth    интерфейс управления задачей осцилографа
 * */
void rx_controller(
        const ethernet_packet_info_t rx_info,
        client ethernet_tx_if i_tx,
        client tile0_switches_if i_sw,
        client osc_eth_if i_osc_eth);

/* Функция читает Ethernet адрес приемника
 * eth_pack[]   Ethernet пакет
 * */
uint64_t DstMac(const uint8_t eth_pack[MTU]);

/* Функция читает Ethernet адрес источника
 * eth_pack[]   Ethernet пакет
 * */
uint64_t SrcMac(const uint8_t eth_pack[MTU]);

/* Функция читает тип Ethernet пакета
 * eth_pack[]   Ethernet пакет
 * */
uint16_t EthType(const uint8_t eth_pack[MTU]);

/* Функция читает версию IP протокола
 * eth_pack[]   Ethernet пакет
 * */
uint8_t IPVer(const uint8_t eth_pack[MTU]);

/* Функция читает длину заголовка IP пакета
 * eth_pack[]   Ethernet пакет
 * */
uint8_t IPHeaderLen(const uint8_t eth_pack[MTU]);

/* Функция читает поле TotalLen IP пакета
 * eth_pack[]   Ethernet пакет
 * */
uint16_t TotalLen(const uint8_t eth_pack[MTU]);

/* Функция читает уникальный идентификатор IP пакета
 * eth_pack[]   Ethernet пакет
 * */
uint16_t ID(const uint8_t eth_pack[MTU]);

/* Функция читает тип вложенного в IP пакет протокола
 * eth_pack[]   Ethernet пакет
 * */
uint8_t Protocol(const uint8_t eth_pack[MTU]);

/* Функция читает поле контрольной суммы IP пакета
 * eth_pack[]   Ethernet пакет
 * */
uint16_t HChecksum(const uint8_t eth_pack[MTU]);

/* Функция читает IP адрес источника
 * eth_pack[]   Ethernet пакет
 * */
uint32_t SrcIP(const uint8_t eth_pack[MTU]);

/* Функция читает IP адрес приемника
 * eth_pack[]   Ethernet пакет
 * */
uint32_t DstIP(const uint8_t eth_pack[MTU]);

/* Функция читает UDP порт источника
 * eth_pack[]   Ethernet пакет
 * */
uint16_t SrcPort(const uint8_t eth_pack[MTU]);

/* Функция читает UDP порт приемника
 * eth_pack[]   Ethernet пакет
 * */
uint16_t DstPort(const uint8_t eth_pack[MTU]);

/* Функция читает размер данных в UDP пакете
 * eth_pack[]   Ethernet пакет
 * */
uint16_t Length(const uint8_t eth_pack[MTU]);

/* Функция читает контрольную сумму UDP пакета
 * eth_pack[]   Ethernet пакет
 * */
uint16_t Checksum(const uint8_t eth_pack[MTU]);

//const uint8_t* alias UdpData(const uint8_t eth_pack[MTU]) { return &eth_pack[42]; }

/* Посылка широковещательного ARP запроса
 * i_tx     интерфейс посылки данных
 * my_mac   Ethernet адрес устройства
 * TPA      удаленный IP адрес
 * */
void SendARPReq(client ethernet_tx_if i_tx, uint64_t my_mac, uint32_t TPA);

/* Посылка одноадресного ARP запроса, когда удаленный Ethernet адрес уже известен (обновление таблицы адресов)
 * i_tx     интерфейс посылки данных
 * */
void SendARPReq2(client ethernet_tx_if i_tx);

/* Посылка оповещения о занятом IP адресе
 * i_tx     интерфейс посылки данных
 * my_mac   Ethernet адрес устройства
 */
void SendARPAnnounce(client ethernet_tx_if i_tx, uint64_t my_mac);

/* Посылка ответа на ARP запрос
 * i_tx     интерфейс посылки данных
 * THA      целевой (удаленный) Ethernet адрес
 * my_mac   Ethernet адрес устройства
 * TPA      целевой (удаленный) IP адрес
 */
void SendARPReply(client ethernet_tx_if i_tx, uint64_t THA, uint64_t my_mac, uint32_t TPA);

/* Посылка тестового UDP пакета
 * i_tx     интерфейс посылки данных
 * data     посылаемое в UDP пакете значение
 */
void TestUdp(client ethernet_tx_if i_tx, uint32_t data);

#endif /* RX_CONT_H_ */
