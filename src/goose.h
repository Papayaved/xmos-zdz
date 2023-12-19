#ifndef GOOSE_H_
#define GOOSE_H_

#include "all_libs.h"
#include "my_types.h"
#include "defines.h"

#define DEFAULT_GOOSE_LEN (272) // ������ ������� GOOSE ������ �� ���������
#define GOOSE_ETHER_TYPE (0x88b8)
#define VLAN_ETHER_TYPE (0x8100)

#define DEFAULT_T_MIN (10) // ms - ����������� ������ �������� GOOSE ���������
#define DEFAULT_T_MAX (1000) // ms - ������������ ������ �������� GOOSE ���������

#define ATT_NUM (12) // �������������� ���������� ���������� ������� APDU
#define BOOLEAN_NUM (4) // ���������� �������������� �������� Boolean ��������� allData
#define VISIBLE_NUM (3) // ���������� �������������� �������� Visible string ��������� allData

typedef enum {ALARM_BIT0 = 1<<0, ALARM_BIT1 = 1<<1, ALARM_BIT2 = 1<<2, TEST_BIT = 1<<3, NO_FLAGS_BIT = 1<<4} GOOSE_BITS;

/* ��������� ������� � ������ ������������ � ���� GOOSE */
typedef interface goose_if {
    // ������ ������ ������������ ������
    [[notification]] slave void goose_rdy();

    // ������ �������� ���������
    [[clears_notification]] GOOSE_BITS get_flags();
} goose_if;

/* ��������� ����������� ������������ ������ GOOSE */
typedef struct {
    uint8_t type; // ��� �������
    uint16_t length; // ����� ������ �������
    uint16_t pos; // ������������ ������� � ������
    uint16_t startIndex; // ������������ ��������� � ����� ������ � ������
} GooseObject;

/* ������� ���������� �������� ������ ��������� ��� �������
 * ���������
 *      TRUE     ������ ��������� (�������� ������ ������� GooseObject)
 *      FALSE    ������ ������� (�������� ������)
 */
BOOL isConstructed(const GooseObject& o);

/* ������� ���������� �������� �� ������ ���� APDU */
BOOL isApp(const GooseObject& o);

/* ������� ���������� �������� �� ������ ���� Context specific (������ ���� allData) */
BOOL isSpecific(const GooseObject& o);

/* ����� �������*/
uint8_t TagNum(const GooseObject& o);

/* ��������� ����������� ������ Application � VLAN
 * (Application � VLAN ���������� ��� �������� �������������)
 * */
typedef struct {
    uint16_t vlan_h; // ��������� VLAN
    uint16_t id; // ����� Application
    uint16_t startIndex; // ������ ��������� ������
    uint16_t length; // ����� ������
    uint32_t reserved; // ��������� ����
    BOOL vlan; // ���./����. VLAN
} GooseApp;

/* ��������� ����������� GOOSE ����� */
typedef struct {
    GooseApp app; // ������ ����������� Application
    GooseObject apdu; // ������ ����������� APDU
    GooseObject att[ATT_NUM]; // ������� ����������� ��������� ADU
//    GooseObject gocbRef, timeAllowedToLive, datSet, goID,  T, stNum, sqNum, simulation, confRev, ndsCom, numDatSetEntries;
//    GooseObject allData;
    GooseObject enumerated; // ������ ����������� �������� ����������
    GooseObject boolean[BOOLEAN_NUM]; // ������� Boolean
    GooseObject visible_str[VISIBLE_NUM]; // ������� Visible string � ������������� ������� (Model, SN, soft_version)
    GooseObject octet_str; // ������ ������ ���������� �����
} GooseObjects;

/* ��������� ���������� GOOSE ����� */
typedef struct {
    uint8_t data[MTU]; // ethernet �����
    uint16_t length; // ����� ������
    GooseObjects obj; // ������� GooseObject ������������ � ������
} GoosePacket;

// ������� GOOSE �����
extern GoosePacket main_goose;

// GOOSE ����� ��� ������������
extern GoosePacket osc_packet;

// GOOSE ����� �� ���������
extern const uint8_t DEFAULT_GOOSE[DEFAULT_GOOSE_LEN];

/* ������ ������� Ethernet ������ ������������� � ���� ������
 * ������� ��������� ������������� ���� GooseObject ��� ������� ��������� �� ������
 * packet       ��������� ���������� ����� ������ Ethernet � ������������ �������� ��� ���������
 * length       ����� ������ Ethernet
 * print_ena    ������ ���������� ����������
*/
BOOL ParseGoose(GoosePacket& packet, unsigned length, BOOL print_ena);

/* �������� �������� GOOSE ������ �� ���������� ���������� ����� ������
 * ���������
 * TRUE     ����� ����� ������������ � �������� ����������
 * FALSE    ����� �� ����� ������������ � �������� ����������
 */
BOOL CheckGooseTemplate(const GoosePacket& packet);

/* ������� ���������� Ethernet ����� �� ������ ������� GOOSE ������ � ��������� � ���� ��������������� ������
 * rx_goose     ������� GOOSE �����
 * tx_data      ����������� ������ ������
 * tx_len       ����� ������� ������
 * tx_buf       ��������������� Ethernet �����
 * ���������    ����� ���������������� ������
 */
unsigned GenerateGoose(
        GoosePacket& rx_goose, const uint8_t tx_data[tx_len], unsigned tx_len,
        uint8_t tx_buf[MTU]);

/* ������� ���������� MAC ����� ��������� � Ethernet �����
 * packet   Ethernet �����
 * n        ������ Ethernet ������
 * srcMac   MAC ����� ���������
 */
void SetPacketSrcMac(uint8_t packet[n], unsigned n, const uint64_t& srcMac);

/* ������� ���������� MAC ����� ���������� � Ethernet �����
 * packet   Ethernet �����
 * n        ������ Ethernet ������
 * srcMac   MAC ����� ����������
 */
void SetPacketDstMac(uint8_t packet[n], unsigned n, const uint64_t& dstMac);

/* ������� ���������� MAC ����� ��������� � GOOSE �����
 * goose    GOOSE �����
 * srcMac   MAC ����� ���������
 */
void SetSrcMac(GoosePacket& goose, const uint64_t& srcMac);

/* ������� ���������� MAC ����� ���������� � GOOSE �����
 * goose    GOOSE �����
 * srcMac   MAC ����� ����������
 */
void SetDstMac(GoosePacket& goose, const uint64_t& dstMac);

// APDU
// ����� ������� ��������������� �������� ���������� �������� APDU

/* ������� ���������� ������ � ���� GoCBRef �� ����� ��� ������
 * goose    ���������� GOOSE �����
 * str      ������
 * str_len  ����� ������
 */
void SetGoCBRef(GoosePacket& goose, const uint8_t str[str_len], unsigned str_len);

/* ������� ���������� ������ � ���� DatSet �� ����� ��� ������
 * goose    ���������� GOOSE �����
 * str      ������
 * str_len  ����� ������
 */
void SetDatSet(GoosePacket& goose, const uint8_t str[str_len], unsigned str_len);

/* ������� ���������� ������ � ���� GoID �� ����� ��� ������
 * goose    ���������� GOOSE �����
 * str      ������
 * str_len  ����� ������
 */
void SetGoID(GoosePacket& goose, const uint8_t str[str_len], unsigned str_len);

/* ������� ���������� �������� � ���� TimeAllowedToLive
 * goose    ���������� GOOSE �����
 * value    �������� � �������������
 */
void SetTimeAllowedToLive(GoosePacket& goose, uint32_t value);

/* ������� ���������� ����� � ���� T
 * goose        ���������� GOOSE �����
 * sec          �������
 * fractions    ���� �������
 * TimeQuality  ��������
 */
void SetT(GoosePacket& goose, uint32_t sec, uint32_t fractions, uint8_t TimeQuality);

/* ������� ���������� �������� � ���� StNum
 * goose    ���������� GOOSE �����
 * value    ��������
 */
void SetStNum(GoosePacket& goose, uint32_t value);

/* ������� ���������� �������� � ���� SqNum
 * goose    ���������� GOOSE �����
 * value    ��������
 */
void SetSqNum(GoosePacket& goose, uint32_t value);

uint32_t GetSqNum(const GoosePacket& goose);

/* ������� ���������� �������� � ���� NumDatSetEntries
 * goose    ���������� GOOSE �����
 * value    ��������
 */
void SetNumDatSetEntries(GoosePacket& goose, uint32_t value);

/* ������� ���������� �������� ���� NumDatSetEntries
 * goose    GOOSE �����
 */
uint32_t GetNumDatSetEntries(const GoosePacket& goose);

// AllData
// ����� ������� ��� ������ � ������ allData

/* ������� ���������� �������� � ���� Enumerated
 * goose    ���������� GOOSE �����
 * value    ��������
 */
void SetEnumerated(GoosePacket& goose, int8_t value);

/* ������� ���������� �������� � ���� Boolean
 * goose    ���������� GOOSE �����
 * flags    ������� �����
 */
void SetBoolean(GoosePacket& goose, unsigned flags);

/* ������� ���������� ������ � ������ ���� Visible string
 * goose    ���������� GOOSE �����
 * str      ������
 * str_len  ����� ������
 */
void SetModel(GoosePacket& goose, const uint8_t* const str, unsigned len);

/* ������� ���������� ������ �� ������ ���� Visible string
 * goose    ���������� GOOSE �����
 * str      ������
 * str_len  ����� ������
 */
void SetSN(GoosePacket& goose, const uint8_t* const str, unsigned len);

/* ������� ���������� ������ � ������ ���� Visible string
 * goose    ���������� GOOSE �����
 * str      ������
 * str_len  ����� ������
 */
void SetVersion(GoosePacket& goose, uint32_t value);

/* ������� ���������� GOOSE ����� ��� ������������� �� ��������� ������� GOOSE ������
 * ������� ������� ��� �������� allData � ��������� ���� Octet string ��������� ������� ��� ��������������� ������
 * ref      ������� GOOSE �����
 * my_mac   MAC ����� ����������
 * size     ������ ������� ��� ��������������� ������
 * osc      GOOSE ����� ��� ������������
 */
BOOL GenerateGooseOsc(const GoosePacket& ref, unsigned size, GoosePacket& osc);

#endif /* GOOSE_H_ */
