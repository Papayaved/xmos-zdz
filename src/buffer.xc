#include "buffer.h"

/* Буфер приема данных совмещенный с полями GOOSE пакета
 * Хранить move указатель на буфер в xC не вижу смысла, т.к. отдельно буфером пользоваться становиться не возможно
 * */
GoosePacket rx_goose;
//uint8_t (* const rx_buf)[MTU] = &rx_goose.data;

// private iterator приемного буфера
static unsigned rx_it;

void init_rx_buf(unsigned rx_start_pos) {
    rx_it = rx_start_pos;
}

uint32_t read_uint32() {
    uint32_t res;
    uint8_t* const ptr = (uint8_t*)&res;

    if (rx_it + 4 <= MTU)
        for (int i = 0; i < 4; i++)
            ptr[i] = rx_goose.data[rx_it++];
    else
        res = 0;

    return res;
}

uint64_t read_uint64() {
    uint64_t res;
    uint8_t* const ptr = (uint8_t*)&res;

    if (rx_it + 8 <= MTU)
        for (int i = 0; i < 8; i++)
            ptr[i] = rx_goose.data[rx_it++];
    else
        res = 0;

    return res;
}

uint8_t read_uint8() {
    if (rx_it < MTU)
        return rx_goose.data[rx_it++];
    else
        return 0;
}

BOOL read_range(uint8_t data[n], unsigned n) {
    if (rx_it + n <= MTU) {
        memcpy(data, &rx_goose.data[rx_it], n);
        rx_it += n;
        return TRUE;
    }
    else
        return FALSE;
}

const uint8_t* alias get_read_ptr() { return &rx_goose.data[rx_it]; }
BOOL check_read_size(unsigned n) { return rx_it + n <= MTU; }

// private iterator передающего буфера
static unsigned tx_it;
uint8_t tx_buf[MTU];

void init_tx_buf(unsigned tx_start_pos) {
    tx_it = tx_start_pos;
}

int get_tx_pos() { return tx_it; }

void add_uint32(uint32_t data) {
    uint8_t* const ptr = (uint8_t*)&data;

    if (tx_it + 4 <= MTU) {
        for (int i = 0; i < 4; i++)
            tx_buf[tx_it++] = ptr[i];
    }
}

void add_uint8(int8_t data) {
    if (tx_it < MTU)
        tx_buf[tx_it++] = data;
}

void add_range(const uint8_t data[n], unsigned n) {
    if (tx_it + n <= MTU) {
        memcpy(&tx_buf[tx_it], data, n);
        tx_it += n;
    }
}

// Auxiliary functions
uint64_t byterev48(const uint8_t* const p_begin) {
    uint64_t res;
    uint8_t* const ptr = (uint8_t*)&res;
    ptr[7] = 0;
    ptr[6] = 0;
    ptr[5] = p_begin[0];
    ptr[4] = p_begin[1];
    ptr[3] = p_begin[2];
    ptr[2] = p_begin[3];
    ptr[1] = p_begin[4];
    ptr[0] = p_begin[5];
    return res;
}

uint32_t byterev32(const uint8_t* const p_begin) {
    uint32_t res;
    uint8_t* const ptr = (uint8_t*)&res;
    ptr[3] = p_begin[0];
    ptr[2] = p_begin[1];
    ptr[1] = p_begin[2];
    ptr[0] = p_begin[3];
    return res;
}

uint16_t byterev16(const uint8_t* const p_begin) {
    uint16_t res;
    uint8_t* const ptr = (uint8_t*)&res;
    ptr[1] = p_begin[0];
    ptr[0] = p_begin[1];
    return res;
}

void write_byterev48(uint8_t* const p_begin, uint64_t value) {
    uint8_t* const ptr = (uint8_t*)&value;
    p_begin[0] = ptr[5];
    p_begin[1] = ptr[4];
    p_begin[2] = ptr[3];
    p_begin[3] = ptr[2];
    p_begin[4] = ptr[1];
    p_begin[5] = ptr[0];
}

void write_byterev32(uint8_t* const p_begin, uint32_t value) {
    uint8_t* const ptr = (uint8_t*)&value;
    p_begin[0] = ptr[3];
    p_begin[1] = ptr[2];
    p_begin[2] = ptr[1];
    p_begin[3] = ptr[0];
}

void write_byterev16(uint8_t* const p_begin, uint16_t value) {
    uint8_t* const ptr = (uint8_t*)&value;
    p_begin[0] = ptr[1];
    p_begin[1] = ptr[0];
}

void write64(uint8_t* const p_begin, uint64_t& value) {
    memcpy(p_begin, (const uint8_t*)&value, sizeof(uint64_t));
}
