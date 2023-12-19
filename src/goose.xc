#include "goose.h"
#include "flash.h"
#include "aux_func.h"

// Штатный GOOSE пакет и пакет для осциллограмм
GoosePacket main_goose, osc_packet;

/* Шаблон GOOSE пакета по умолчанию
 * GOOSE multicast addresses
 * 01-0C-CD-01-00-00 ... 01-0C-CD-01-01-FF
 */
const uint8_t DEFAULT_GOOSE[DEFAULT_GOOSE_LEN] = {
    0x01, 0x0c, 0xcd, 0x01, 0x00, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x88, 0xB8,
    0x00, 0x01,
    0x00, 0xFE,
    0x00, 0x00,
    0x00, 0x00,
    0x61, 0x81, 0xF7,
    0x80, 0x0D, 0x67, 0x6F, 0x43, 0x42, 0x52, 0x65, 0x66, 0x20, 0x76, 0x61, 0x6C, 0x75, 0x65,
    0x81, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x82, 0x0C, 0x64, 0x61, 0x74, 0x53, 0x65, 0x74, 0x20, 0x76, 0x61, 0x6C, 0x75, 0x65,
    0x83, 0x0A, 0x67, 0x6F, 0x49, 0x64, 0x20, 0x76, 0x61, 0x6C, 0x75, 0x65,
    0x84, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x85, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x86, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x87, 0x01, 0x00,
    0x88, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x89, 0x01, 0x00,
    0x8A, 0x05, 0x00, 0x00, 0x00, 0x00, 0x0D,
    0xAB, 0x81, 0x98,
    0x85, 0x02, 0x00, 0x00,
    0x84, 0x03, 0x03, 0x00, 0x00,
    0x83, 0x01, 0x00,
    0x84, 0x03, 0x03, 0x00, 0x00,
    0x83, 0x01, 0x00,
    0x84, 0x03, 0x03, 0x00, 0x00,
    0x83, 0x01, 0x00,
    0x84, 0x03, 0x03, 0x00, 0x00,
    0x83, 0x01, 0x00,
    0x84, 0x03, 0x03, 0x00, 0x00,
    0x8A, 0x23, 0x4F, 0x72, 0x69, 0x6F, 0x6E, 0x5A, 0x44, 0x5A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00,
    0x8A, 0x23, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00,
    0x8A, 0x23, 0x31, 0x30, 0x2E, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00
};

/* Чтение Little-Endian значения из массива
 * b    массив байт
 * n    размер массива
 * it   вход: индекс начального элемента, выход: индекс следующий за прочитанным значением
 * результат
 * прочитанное значение
 */
static uint16_t read_le_u16(const uint8_t b[n], unsigned n, unsigned& it) {
    uint16_t res;
    uint8_t* const ptr = (uint8_t*)&res;
    ptr[1] = b[it++];
    ptr[0] = b[it++];
    return res;
}

/* Чтение Little-Endian значения из массива
 * b    массив байт
 * n    размер массива
 * it   вход: индекс начального элемента, выход: индекс следующий за прочитанным значением
 * результат
 * прочитанное значение
 */
static uint16_t read_le_u32(const uint8_t b[n], unsigned n, unsigned& it) {
    uint32_t res;
    uint8_t* const ptr = (uint8_t*)&res;
    ptr[3] = b[it++];
    ptr[2] = b[it++];
    ptr[1] = b[it++];
    ptr[0] = b[it++];
    return res;
}

/* Функция инициализирует структуру GooseObject из массива байт
 * buf      массив с GOOSE пакетом
 * n        размер GOOSE пакета
 * pos      индекс текущей позиции в массиве, результат: позиция следующая за GOOSE объектом
 * o        инициализированная структура GooseObject
 *
 * результат
 * TRUE     структура инициализорована
 * FALSE    ошибка
 */
static BOOL GetGooseObject(const uint8_t buf[n], unsigned n, unsigned& pos, GooseObject& o) {
    o.pos = pos;
    o.type = buf[pos++];

    if ((buf[pos] & 0x80) == 0)
        o.length = buf[pos++];
    else {
        int bytes = buf[pos++] & 0x7f;

        switch (bytes) {
        case 1: o.length = buf[pos++]; break;
        case 2:
            o.length = (uint16_t)buf[pos++]<<8;
            o.length |= buf[pos++];
            break;
        default:
            o.length = 0;
            pos = 0;
            break;
        }
    }
    o.startIndex = pos;

    if (o.startIndex + o.length > n) {
        o.length = 0;
        o.pos = 0;
        o.startIndex = 0;
    }

    if (!isConstructed(o))
        pos += o.length;

    return o.length != 0;
}

/* Функция инициализирует структуру GooseApp из массива байт
 * buf      массив с GOOSE пакетом
 * n        размер GOOSE пакета
 * app      инициализированная структура GooseApp
 *
 * возвращаемое значение
 * TRUE     структура инициализорована
 * FALSE    ошибка
 */
static BOOL GetGooseApp(const uint8_t buf[n], unsigned n, GooseApp& app) {
    BOOL OK = FALSE;
    unsigned it = 12;

    uint16_t ether_type = read_le_u16(buf, n, it);

    if (ether_type == VLAN_ETHER_TYPE) {
        app.vlan = TRUE;
        app.vlan_h = read_le_u16(buf, n, it);
        debug_printf("vlan_h: %x\n", app.vlan_h);
        ether_type = read_le_u16(buf, n, it);
    }

    if (ether_type == GOOSE_ETHER_TYPE) {
        app.id = read_le_u16(buf, n, it);
        app.length = read_le_u16(buf, n, it) - 4;
        app.reserved = read_le_u32(buf, n, it);
        app.startIndex = it;

//        debug_printf("eth_type: %x len: %d\n", ether_type, n);
//        debug_printf("app_id: %d len: %d res %d pos: %d\n", app.id, app.length, app.reserved, app.startIndex);

        OK = app.id == 1 && app.startIndex + app.length <= n && app.reserved == 0;
        if (!OK) {
            app.length = 0;
            debug_printf("ERROR\n");
        }
    }

    return OK;
}

/* Чтение первого объекта GooseObject */
static BOOL GetGooseFirst(const uint8_t buf[n], unsigned n, const GooseApp& app, GooseObject& next) {
    unsigned it = app.startIndex;

    BOOL OK = GetGooseObject(buf, n, it, next);
    OK = OK && next.startIndex + next.length <= app.startIndex + app.length;
    if (!OK)
        debug_printf("ERROR! next.startIndex: %d next.length: %d app.startIndex: %d app.length: %d \n", next.startIndex, next.length, app.startIndex, app.length);
    return OK;
}

/* Чтение первого ребенка объекта GooseObject */
static BOOL GetGooseChild(const uint8_t buf[n], unsigned n, const GooseObject& parent, GooseObject& child) {
    unsigned it = parent.startIndex;
    BOOL OK = GetGooseObject(buf, n, it, child);
    OK = OK && child.startIndex + child.length <= parent.startIndex + parent.length;
    return OK;
}

/* Чтение следующего объекта GooseObject */
static BOOL GetGooseNext(const uint8_t buf[n], unsigned n, const GooseObject& parent, GooseObject& child) {
    unsigned it = child.startIndex + child.length;
    BOOL OK = GetGooseObject(buf, n, it, child);
    OK = OK && child.startIndex + child.length <= parent.startIndex + parent.length;
    return OK;
}

/* Объект GooseObject является последним в списке */
static BOOL isGooseLast(const GooseObject& parent, const GooseObject& o) {
    return o.startIndex + o.length >= parent.startIndex + parent.length;
}

/* Очистка объекта GooseApp */
static void ClearGooseApp(GooseApp& o) {
    memset((uint8_t*)&o, 0, sizeof(GooseApp));
}

/* Очистка объекта GooseObject */
static void ClearGooseObject(GooseObject& o) {
    memset((uint8_t*)&o, 0, sizeof(GooseObject));
}

/* Очистка массива объектов GooseObject */
static void ClearGooseObjects(GooseObject o[n], unsigned n) {
    for (int i = 0; i < n; i++)
        ClearGooseObject(o[i]);
}

/* Очистка объекта GoosePacket */
static void ClearGoosePacket(GoosePacket& packet) {
    packet.length = 0;
    ClearGooseApp(packet.obj.app);
    ClearGooseObject(packet.obj.apdu);
    ClearGooseObjects(packet.obj.att, ATT_NUM);
    ClearGooseObjects(packet.obj.boolean, BOOLEAN_NUM);
    ClearGooseObjects(packet.obj.visible_str, VISIBLE_NUM);
    ClearGooseObject(packet.obj.octet_str);
}

/* Функия разбора Ethernet пакета содержащегося в поле данных
 * Функция заполняет подерживаемые поля GooseObject для быстрой навигации по пакету
 */
BOOL ParseGoose(GoosePacket& packet, unsigned length, BOOL print_ena) {
    ClearGoosePacket(packet);

    BOOL OK = GetGooseApp(packet.data, length, packet.obj.app);

    if (OK) {
        packet.length = length;

        // Print goose packet
        //PrintByteArray(packet.data, packet.length);

        OK = GetGooseFirst(packet.data, packet.length, packet.obj.app, packet.obj.apdu);
        if (print_ena)
            debug_printf("APDU type: 0x%x pos: %d len: %d\n", packet.obj.apdu.type, packet.obj.apdu.startIndex, packet.obj.apdu.length);

        OK = OK && isApp(packet.obj.apdu) && TagNum(packet.obj.apdu) == 1; // first APDU

        GooseObject att;
        if (OK)
            OK = GetGooseChild(packet.data, packet.length, packet.obj.apdu, att);

        while (OK) {
            if (isSpecific(att) && TagNum(att) < ATT_NUM) {
                packet.obj.att[TagNum(att)] = att;

                if (print_ena)
                    debug_printf("Att type: 0x%x pos: %d len: %d\n", att.type, att.startIndex, att.length);

                if (isConstructed(att) && TagNum(att) == 11) {
                    if (print_ena)
                        debug_printf("\tallData:\n");

                    unsigned i = 0, j = 0;
                    GooseObject o;

                    OK = GetGooseChild(packet.data, packet.length, att, o);

                    while (OK) {
                        if (print_ena)
                            debug_printf("Data type: 0x%x pos: %d len: %d\n", o.type, o.startIndex, o.length);

                        if (o.type == 0x85 && o.length == 2) {
                            packet.obj.enumerated = o;

                            if (print_ena)
                                debug_printf("Enum\n");
                        }
                        else if (o.type == 0x83 && o.length == 1 && i < BOOLEAN_NUM) {
                            packet.obj.boolean[i++] = o;

                            if (print_ena)
                                debug_printf("Boolean[%d]\n", i);
                        }
                        else if (o.type == 0x89) {
                            packet.obj.octet_str = o;

                            if (print_ena)
                                debug_printf("Octet str\n");
                        }
                        else if (o.type == 0x8a && o.length == 35 && j < VISIBLE_NUM) {
                            packet.obj.visible_str[j++] = o;

                            if (print_ena)
                                debug_printf("Visible_str[%d]\n", j);
                        }

                        if (isGooseLast(att, o) || !OK) break;

                        OK = GetGooseNext(packet.data, packet.length, att, o);
                    }
                }
            }

            if (isGooseLast(packet.obj.apdu, att) || !OK) break;

            OK = OK && GetGooseNext(packet.data, packet.length, packet.obj.apdu, att);
        }
    }

    if (!OK) ClearGoosePacket(packet);

    return OK;
}

/* Проверка штатного GOOSE пакета на корректное количество полей данных */
BOOL CheckGooseTemplate(const GoosePacket& packet) {
    BOOL OK = TRUE;

    for (int i = 0; i < ATT_NUM; i++)
        OK = OK && packet.obj.att[i].startIndex != 0;

    for (int i = 0; i < BOOLEAN_NUM; i++)
        OK = OK && packet.obj.boolean[i].startIndex != 0;

    OK = OK && packet.obj.enumerated.startIndex != 0;

    for (int i = 0; i < VISIBLE_NUM; i++)
        OK = OK && packet.obj.visible_str[i].startIndex != 0;

    return OK;
}

/* Функция вычисляет размер GooseObject в байтах
 * length   длина данных в байтах
 */
static uint16_t object_size(uint16_t length) {
    return (length >= 256) ? length + 4 : (length >= 128) ? length + 3 : length + 2;
}

/* Функция записывает длину GooseObject в массив
 * packet   GOOSE пакет
 * pos      текущий индекс в GOOSE пакете
 * value    записываеммая длина GooseObject
 */
static void write_object_length(uint8_t packet[MTU], unsigned& pos, uint16_t value) {
    const uint8_t* const ptr = (uint8_t*)&value;

    if (ptr[1]) {
        packet[pos++] = 0x82;
        packet[pos++] = ptr[1];
        packet[pos++] = ptr[0];
    }
    else if (ptr[0] & 0x80) {
        packet[pos++] = 0x81;
        packet[pos++] = ptr[0];
    }
    else
        packet[pos++] = ptr[0];
}

// todo: copy object by object
/* Функция генерирует Ethernet пакет на основе другого GOOSE пакета и добавляет в него технологические данные */
unsigned GenerateGoose(
        GoosePacket& rx_goose, const uint8_t tx_data[tx_len], unsigned tx_len,
        uint8_t tx_buf[MTU])
{
    uint32_t sqNum = GetSqNum(rx_goose);
    SetSqNum(rx_goose, ++sqNum);

    memcpy(&tx_buf[0], &rx_goose.data[6], 6); // change src & dst MAC
    memcpy(&tx_buf[6], &rx_goose.data[0], 6);
    memcpy(&tx_buf[12], &rx_goose.data[12], rx_goose.obj.app.startIndex - 12); // copy VLAN, ether_type, reserved

    int allData_len = rx_goose.obj.att[11].length;
    allData_len -= object_size(rx_goose.obj.octet_str.length);

    int octet_str_size = object_size(tx_len);

    allData_len += octet_str_size;

    int allData_size = object_size(allData_len);

    uint16_t apdu_len = rx_goose.obj.apdu.length;
    apdu_len -= object_size(rx_goose.obj.att[11].length);
    apdu_len += allData_size;

    int apdu_size = object_size(apdu_len);
    int app_len = apdu_size + 4;

    unsigned it = rx_goose.obj.app.startIndex - 6;
    tx_buf[it++] = (uint8_t)(app_len>>8);
    tx_buf[it++] = (uint8_t)(app_len);
    it += 4;

    tx_buf[it++] = 0x61; // apdu 1
    write_object_length(tx_buf, it, apdu_len);

    // copy from begin to allData
    int start = rx_goose.obj.apdu.startIndex;
    int end = rx_goose.obj.att[11].pos;
    int size = end - start;

    if (size > 0) {
        memcpy(&tx_buf[it], &rx_goose.data[start], size);
        it += size;
    }

    tx_buf[it++] = 0xAB; // allData
    write_object_length(tx_buf, it, allData_len);

    // copy from begin to octet string
    start = rx_goose.obj.att[11].startIndex;
    end = rx_goose.obj.octet_str.pos;
    size = end - start;

    if (size > 0) {
        memcpy(&tx_buf[it], &rx_goose.data[start], size);
        it += size;
    }

    tx_buf[it++] = 0x89; // octet_str
    write_object_length(tx_buf, it, tx_len);
    memcpy(&tx_buf[it], tx_data, tx_len);
    it += tx_len;

    // copy from octet string to end
    start = rx_goose.obj.octet_str.startIndex + rx_goose.obj.octet_str.length;
    end = rx_goose.length;
    size = end - start;

    if (size > 0) {
        memcpy(&tx_buf[it], &rx_goose.data[start], size);
        it += size;
    }

    return it;
}

//
void SetPacketSrcMac(uint8_t packet[n], unsigned n, const uint64_t& srcMac) {
    const uint8_t* const ptr = (const uint8_t*)&srcMac;

    for (int i = MACADDR_NUM_BYTES, j = MACADDR_NUM_BYTES - 1; i < 2 * MACADDR_NUM_BYTES; i++, j--)
        packet[i] = ptr[j];
}

void SetSrcMac(GoosePacket& goose, const uint64_t& srcMac) {
    SetPacketSrcMac(goose.data, MTU, srcMac);
}

void SetPacketDstMac(uint8_t packet[n], unsigned n, const uint64_t& dstMac) {
    const uint8_t* const ptr = (const uint8_t*)&dstMac;

    for (int i = 0, j = MACADDR_NUM_BYTES - 1; i < MACADDR_NUM_BYTES; i++, j--)
        packet[i] = ptr[j];
}

void SetDstMac(GoosePacket& goose, const uint64_t& dstMac) {
    SetPacketDstMac(goose.data, MTU, dstMac);
}

//
void SetGoCBRef(GoosePacket& goose, const uint8_t str[str_len], unsigned str_len) {
    GooseObject& o = goose.obj.att[0];
    if (o.length && str_len)
        memcpy(&goose.data[o.startIndex], str, MIN(str_len, o.length));
}

void SetDatSet(GoosePacket& goose, const uint8_t str[str_len], unsigned str_len) {
    GooseObject& o = goose.obj.att[2];
    if (o.length && str_len)
        memcpy(&goose.data[o.startIndex], str, MIN(str_len, o.length));
}

void SetGoID(GoosePacket& goose, const uint8_t str[str_len], unsigned str_len) {
    GooseObject& o = goose.obj.att[3];
    if (o.length && str_len)
        memcpy(&goose.data[o.startIndex], str, MIN(str_len, o.length));
}

// запись в массив значения GooseObject
static void SetInt8(uint8_t* data, const GooseObject& o, int8_t value) {
    if (o.length >= 2)
        data[o.startIndex + 1] = value;
}

// запись в массив значения GooseObject
static void SetUInt32_rev(uint8_t* data, const GooseObject& o, uint32_t value) {
    if (o.length >= 5) {
        int i = o.startIndex + 1;
        const uint8_t* const ptr = (uint8_t*)&value;
        data[i++] = ptr[3];
        data[i++] = ptr[2];
        data[i++] = ptr[1];
        data[i] = ptr[0];
    }
}

// запись в массив значения GooseObject
static void SetUtcTime_rev(uint8_t* data, const GooseObject& o, uint32_t sec, uint32_t fractions, uint8_t TimeQuality) {
    if (o.length >= 8) {
        const uint8_t* const p_sec = (uint8_t*)&sec;
        const uint8_t* const p_frac = (uint8_t*)&fractions;

        for (int i = o.startIndex, j = 3; j >= 0; i++, j--)
            data[i] = p_sec[j];

        for (int i = o.startIndex + sizeof(uint32_t), j = 2; j >= 0; i++, j--)
            data[i] = p_frac[j];

        data[o.startIndex + 7] = TimeQuality;
    }
}

// чтение значения из буфера в реверсивном порядке байт
static uint32_t read_uint32_rev(const uint8_t* const buf, unsigned pos) {
    uint32_t data;
    uint8_t* rcv = (uint8_t*)&data;
    const uint8_t* const src = buf + pos;
    rcv[3] = src[0];
    rcv[2] = src[1];
    rcv[1] = src[2];
    rcv[0] = src[3];
    return data;
}

void SetTimeAllowedToLive(GoosePacket& goose, uint32_t value) {
    SetUInt32_rev(goose.data, goose.obj.att[1], value);
}

void SetT(GoosePacket& goose, uint32_t sec, uint32_t fractions, uint8_t TimeQuality) {
    SetUtcTime_rev(goose.data, goose.obj.att[4], sec, fractions, TimeQuality);
}

void SetStNum(GoosePacket& goose, uint32_t value) {
    SetUInt32_rev(goose.data, goose.obj.att[5], value);
}

void SetSqNum(GoosePacket& goose, uint32_t value) {
    SetUInt32_rev(goose.data, goose.obj.att[6], value);
}

uint32_t GetSqNum(const GoosePacket& goose) {
    GooseObject& o = goose.obj.att[6];
    return o.length != 0 ? read_uint32_rev(goose.data, o.startIndex + 1) : 0;
}

// AllData
void SetEnumerated(GoosePacket& goose, int8_t value) {
    SetInt8(goose.data, goose.obj.enumerated, value);
}

void SetBoolean(GoosePacket& goose, unsigned flags) {
    GooseObject (& b)[BOOLEAN_NUM] = goose.obj.boolean;

    for (int i = 0; i < BOOLEAN_NUM; i++, flags >>= 1)
        if (b[i].length != 0)
            goose.data[b[i].startIndex] = (uint8_t)(flags & 1);
}

/* Запись строки в поле VisibleString
 * goose    GOOSE пакет
 * index    номер значения
 * str      строка
 * str_len  размер строки
 */
static void SetVisibleString(GoosePacket& goose, unsigned index, const uint8_t* const str, unsigned str_len) {
    if (index < VISIBLE_NUM) {
        GooseObject& o = goose.obj.visible_str[index];
        unsigned size = MIN(str_len, o.length);
        uint8_t* const ptr = &goose.data[o.startIndex];

        if (size != 0) {
            memcpy(ptr, str, size);

            if (size < o.length)
                memset(ptr + size, 0, o.length - size);
        }
    }
}

void SetModel(GoosePacket& goose, const uint8_t* const str, unsigned len) {
    SetVisibleString(goose, 0, str, len);
}

void SetSN(GoosePacket& goose, const uint8_t* const str, unsigned len) {
    SetVisibleString(goose, 1, str, len);
}

void SetVersion(GoosePacket& goose, uint32_t value) {
    uint8_t buffer[8];
    memset(buffer, 0, sizeof(buffer));
    snprintf(buffer, sizeof(buffer), "%d.%02d", (uint8_t)(value >> 24 & 0x3F), (uint8_t)(value >> 16));
    SetVisibleString(goose, 2, buffer, sizeof(buffer) - 1);
}

uint32_t GetNumDatSetEntries(const GoosePacket& goose) {
    GooseObject& o = goose.obj.att[10];
    return o.length != 0 ? read_uint32_rev(goose.data, o.startIndex + 1) : 0;
}

void SetNumDatSetEntries(GoosePacket& goose, uint32_t value) {
    SetUInt32_rev(goose.data, goose.obj.att[10], value);
}

BOOL isConstructed(const GooseObject& o) { return (o.type & 0x20) != 0 && o.length != 0; }
BOOL isApp(const GooseObject& o) { return (o.type & 0xE0) == 0x60 && o.length != 0; }
BOOL isSpecific(const GooseObject& o) { return (o.type & 0xC0) == 0x80 && o.length != 0; }
uint8_t TagNum(const GooseObject& o) { return o.type & 0x1F; }

// Функция генерирует GOOSE пакет для осциллограммы на основание другого GOOSE пакета
BOOL GenerateGooseOsc(const GoosePacket& ref, unsigned data_size, GoosePacket& osc) {
    debug_printf("Osc packet generate...\n");

    memcpy(&osc.data[12], &ref.data[12], ref.obj.app.startIndex - 12); // copy VLAN, ether_type, reserved

    int octet_str_size = object_size(data_size);
    int allData_len = octet_str_size;
    int allData_size = object_size(allData_len);

    uint16_t apdu_len = ref.obj.apdu.length;
    apdu_len -= object_size(ref.obj.att[11].length);
    apdu_len += allData_size;

    int apdu_size = object_size(apdu_len);
    int app_len = apdu_size + 4;

    unsigned it = ref.obj.app.startIndex - 6; // to app length
    osc.data[it++] = (uint8_t)(app_len>>8);
    osc.data[it++] = (uint8_t)(app_len);
    it += 4; // reserved

    osc.data[it++] = 0x61; // apdu 1
    write_object_length(osc.data, it, apdu_len);

    // copy from begin to allData
    int start = ref.obj.apdu.startIndex;
    int end = ref.obj.att[11].pos;
    int size = end - start;

    if (size > 0) {
        memcpy(&osc.data[it], &ref.data[start], size);
        it += size;
    }

    osc.data[it++] = 0xAB; // allData
    write_object_length(osc.data, it, allData_len);

    osc.data[it++] = 0x89; // octet_str
    write_object_length(osc.data, it, data_size);
    memset(&osc.data[it], 0x00, data_size);
    it += data_size;

    BOOL OK = ParseGoose(osc, it, TRUE);

    if (OK) {
//        SetTimeAllowedToLive(osc, 3 * DEFAULT_T_MAX);
        SetNumDatSetEntries(osc, 1);
        debug_printf("OK\n");
    }
    else
        debug_printf("ERROR\n");

    return OK;
}
