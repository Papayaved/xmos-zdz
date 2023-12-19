#include "aux_func.h"

// Auxiliary functions

// Распечатка к консоль массива байт
void PrintByteArray(const uint8_t ar[n], unsigned n) {
    int i = 0;
    for (; i < n; i++) {
        if ((i & 7) == 0) debug_printf("%03x: ", i);
        debug_printf("%02x", ar[i]);
        if ((i & 7) == 7)
            debug_printf("\n");
        else
            debug_printf(" ");
    }
    if ((i & 7) != 7)
        debug_printf("\n");
}

// Функция расчета CRC16 для ModRTU
uint16_t ModRTU_CRC(const uint8_t* const ptr, int len) {
    uint16_t crc = 0xFFFF;

    for (int pos = 0; pos < len; pos++) {
        crc ^= (uint16_t)ptr[pos];

        for (int i = 8; i != 0; i--) {
            if ((crc & 0x0001) != 0) {
                crc >>= 1;
                crc ^= 0xA001;
            }
            else
                crc >>= 1;
        }
    }
    return crc;
}

// Integer logarithm
int ilog2(uint64_t value) {
    int i;
    for (i = -1; value != 0; i++)
        value >>= 1;

    return (i == -1) ? 0 : i;
}
