#ifndef GOOSE_H_
#define GOOSE_H_

#include "all_libs.h"
#include "my_types.h"
#include "defines.h"

#define DEFAULT_GOOSE_LEN (272) // размер шаблона GOOSE пакета по умолчанию
#define GOOSE_ETHER_TYPE (0x88b8)
#define VLAN_ETHER_TYPE (0x8100)

#define DEFAULT_T_MIN (10) // ms - минимальный период передачи GOOSE сообщений
#define DEFAULT_T_MAX (1000) // ms - максимальный период передачи GOOSE сообщений

#define ATT_NUM (12) // поддерживаемое количество аттрибутов объекта APDU
#define BOOLEAN_NUM (4) // Количество поддерживаемых объектов Boolean аттрибута allData
#define VISIBLE_NUM (3) // Количество поддерживаемых объектов Visible string аттрибута allData

typedef enum {ALARM_BIT0 = 1<<0, ALARM_BIT1 = 1<<1, ALARM_BIT2 = 1<<2, TEST_BIT = 1<<3, NO_FLAGS_BIT = 1<<4} GOOSE_BITS;

/* Интерфейс доступа к данным отправляемым в сеть GOOSE */
typedef interface goose_if {
    // запрос чтения изменившихся данных
    [[notification]] slave void goose_rdy();

    // чтение текущего состояния
    [[clears_notification]] GOOSE_BITS get_flags();
} goose_if;

/* Структура описывающая элементарный объект GOOSE */
typedef struct {
    uint8_t type; // тип объекта
    uint16_t length; // длина данных объекта
    uint16_t pos; // распорожение объекта в пакете
    uint16_t startIndex; // расположение вложенных в пакет данных в пакете
} GooseObject;

/* Функция определяет является объект составным или простым
 * Результат
 *      TRUE     объект составной (содержит другие объекты GooseObject)
 *      FALSE    объект простой (содержит данные)
 */
BOOL isConstructed(const GooseObject& o);

/* Функция определяет является ли объект типа APDU */
BOOL isApp(const GooseObject& o);

/* Функция определяет является ли объект типа Context specific (объект поля allData) */
BOOL isSpecific(const GooseObject& o);

/* Номер объекта*/
uint8_t TagNum(const GooseObject& o);

/* Структура описывающая объект Application и VLAN
 * (Application и VLAN объеденены для удобства использования)
 * */
typedef struct {
    uint16_t vlan_h; // заголовок VLAN
    uint16_t id; // номер Application
    uint16_t startIndex; // начало вложенных данных
    uint16_t length; // длина данных
    uint32_t reserved; // резервное поле
    BOOL vlan; // вкл./выкл. VLAN
} GooseApp;

/* Структура описывающая GOOSE пакет */
typedef struct {
    GooseApp app; // объект описывающий Application
    GooseObject apdu; // объект описывающий APDU
    GooseObject att[ATT_NUM]; // объекты описывающие аттрибуты ADU
//    GooseObject gocbRef, timeAllowedToLive, datSet, goID,  T, stNum, sqNum, simulation, confRev, ndsCom, numDatSetEntries;
//    GooseObject allData;
    GooseObject enumerated; // объект описывающий здоровье устройства
    GooseObject boolean[BOOLEAN_NUM]; // объекты Boolean
    GooseObject visible_str[VISIBLE_NUM]; // объекты Visible string с фиксированной длинной (Model, SN, soft_version)
    GooseObject octet_str; // объект данных переменной длины
} GooseObjects;

/* Структура содержащая GOOSE пакет */
typedef struct {
    uint8_t data[MTU]; // ethernet пакет
    uint16_t length; // длина пакета
    GooseObjects obj; // объекты GooseObject содержащиеся в пакете
} GoosePacket;

// Штатный GOOSE пакет
extern GoosePacket main_goose;

// GOOSE пакет для осциллограмм
extern GoosePacket osc_packet;

// GOOSE пакет по умолчанию
extern const uint8_t DEFAULT_GOOSE[DEFAULT_GOOSE_LEN];

/* Функия разбора Ethernet пакета содержащегося в поле данных
 * Функция заполняет подерживаемые поля GooseObject для быстрой навигации по пакету
 * packet       структура содержащая пакет данных Ethernet и незаполненые описания его элементов
 * length       длина пакета Ethernet
 * print_ena    печать отладочной информации
*/
BOOL ParseGoose(GoosePacket& packet, unsigned length, BOOL print_ena);

/* Проверка штатного GOOSE пакета на корректное количество полей данных
 * Результат
 * TRUE     пакет может использовать в качестве шаблонного
 * FALSE    пакет не может использовать в качестве шаблонного
 */
BOOL CheckGooseTemplate(const GoosePacket& packet);

/* Функция генерирует Ethernet пакет на основе другого GOOSE пакета и добавляет в него технологические данные
 * rx_goose     опорный GOOSE пакет
 * tx_data      добавляемый массив данных
 * tx_len       длина массива данных
 * tx_buf       сгенерированный Ethernet пакет
 * результат    длина сгенерированного пакета
 */
unsigned GenerateGoose(
        GoosePacket& rx_goose, const uint8_t tx_data[tx_len], unsigned tx_len,
        uint8_t tx_buf[MTU]);

/* Функция записывает MAC адрес источника в Ethernet пакет
 * packet   Ethernet пакет
 * n        размер Ethernet пакета
 * srcMac   MAC адрес источника
 */
void SetPacketSrcMac(uint8_t packet[n], unsigned n, const uint64_t& srcMac);

/* Функция записывает MAC адрес назначения в Ethernet пакет
 * packet   Ethernet пакет
 * n        размер Ethernet пакета
 * srcMac   MAC адрес назначения
 */
void SetPacketDstMac(uint8_t packet[n], unsigned n, const uint64_t& dstMac);

/* Функция записывает MAC адрес источника в GOOSE пакет
 * goose    GOOSE пакет
 * srcMac   MAC адрес источника
 */
void SetSrcMac(GoosePacket& goose, const uint64_t& srcMac);

/* Функция записывает MAC адрес назначения в GOOSE пакет
 * goose    GOOSE пакет
 * srcMac   MAC адрес назначения
 */
void SetDstMac(GoosePacket& goose, const uint64_t& dstMac);

// APDU
// Серия функций устанавливающих значения аттрибутов объектов APDU

/* Функция записывает строку в поле GoCBRef не меняя его размер
 * goose    изменяемый GOOSE пакет
 * str      строка
 * str_len  длина строки
 */
void SetGoCBRef(GoosePacket& goose, const uint8_t str[str_len], unsigned str_len);

/* Функция записывает строку в поле DatSet не меняя его размер
 * goose    изменяемый GOOSE пакет
 * str      строка
 * str_len  длина строки
 */
void SetDatSet(GoosePacket& goose, const uint8_t str[str_len], unsigned str_len);

/* Функция записывает строку в поле GoID не меняя его размер
 * goose    изменяемый GOOSE пакет
 * str      строка
 * str_len  длина строки
 */
void SetGoID(GoosePacket& goose, const uint8_t str[str_len], unsigned str_len);

/* Функция записывает значение в поле TimeAllowedToLive
 * goose    изменяемый GOOSE пакет
 * value    значение в миллисекундах
 */
void SetTimeAllowedToLive(GoosePacket& goose, uint32_t value);

/* Функция записывает время в поле T
 * goose        изменяемый GOOSE пакет
 * sec          секунды
 * fractions    доли секунды
 * TimeQuality  качество
 */
void SetT(GoosePacket& goose, uint32_t sec, uint32_t fractions, uint8_t TimeQuality);

/* Функция записывает значение в поле StNum
 * goose    изменяемый GOOSE пакет
 * value    значение
 */
void SetStNum(GoosePacket& goose, uint32_t value);

/* Функция записывает значение в поле SqNum
 * goose    изменяемый GOOSE пакет
 * value    значение
 */
void SetSqNum(GoosePacket& goose, uint32_t value);

uint32_t GetSqNum(const GoosePacket& goose);

/* Функция записывает значение в поле NumDatSetEntries
 * goose    изменяемый GOOSE пакет
 * value    значение
 */
void SetNumDatSetEntries(GoosePacket& goose, uint32_t value);

/* Функция возвращает значение поля NumDatSetEntries
 * goose    GOOSE пакет
 */
uint32_t GetNumDatSetEntries(const GoosePacket& goose);

// AllData
// Серия функций для работы с полями allData

/* Функция записывает значение в поле Enumerated
 * goose    изменяемый GOOSE пакет
 * value    значение
 */
void SetEnumerated(GoosePacket& goose, int8_t value);

/* Функция записывает значения в поля Boolean
 * goose    изменяемый GOOSE пакет
 * flags    битовые флаги
 */
void SetBoolean(GoosePacket& goose, unsigned flags);

/* Функция записывает строку в первое поле Visible string
 * goose    изменяемый GOOSE пакет
 * str      строка
 * str_len  длина строки
 */
void SetModel(GoosePacket& goose, const uint8_t* const str, unsigned len);

/* Функция записывает строку во второе поле Visible string
 * goose    изменяемый GOOSE пакет
 * str      строка
 * str_len  длина строки
 */
void SetSN(GoosePacket& goose, const uint8_t* const str, unsigned len);

/* Функция записывает строку в третье поле Visible string
 * goose    изменяемый GOOSE пакет
 * str      строка
 * str_len  длина строки
 */
void SetVersion(GoosePacket& goose, uint32_t value);

/* Функция генерирует GOOSE пакет для осциллограммы на основание другого GOOSE пакета
 * Функция удаляет все элеметны allData и добавляет поле Octet string заданного размера для технологических данных
 * ref      опорный GOOSE пакет
 * my_mac   MAC адрес устройства
 * size     размер массива под технологические данные
 * osc      GOOSE пакет для осциллограмм
 */
BOOL GenerateGooseOsc(const GoosePacket& ref, unsigned size, GoosePacket& osc);

#endif /* GOOSE_H_ */
