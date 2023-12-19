#include "all_libs.h"
#include "relay.h"
//#include "ports.h"

extern out port relays; // непонятная ошибка компилятора

// Вкл/выкл группы реле заданной маской
void relayControlMask(RELAY_MASK_T mask, BOOL enable) {
    static unsigned relay_reg;

    if (enable)
        relay_reg |= mask;
    else
        relay_reg &= ~mask;

    relays <: relay_reg;

    debug_printf("RLY %x\n", relay_reg);
}

// Переключение одиночного реле
void relayControl(unsigned num, BOOL enable) {
    relayControlMask(1U << num, enable);
}

void relayControl2(unsigned num1, unsigned num2, BOOL enable) {
    relayControlMask( (1U << num1) | (1U << num2), enable );
}

void relayControl3(unsigned num1, unsigned num2, unsigned num3, BOOL enable) {
    relayControlMask( (1U << num1) | (1U << num2) | (1U << num3), enable );
}

void relayControl4(unsigned num1, unsigned num2, unsigned num3, unsigned num4, BOOL enable) {
    relayControlMask( (1U << num1) | (1U << num2) | (1U << num3) | (1U << num4), enable );
}
