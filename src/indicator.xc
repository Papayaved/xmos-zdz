#include <platform.h> // не нужна, ошибка компилятора
#include "all_libs.h"
#include "indicator.h"
#include "ports.h"

static unsigned ind_state; // текущее состояние индикаторов

// положение индикаторов в порту
static const unsigned pos[IND_NUM] = {2, 0, 6, 4};

// Функция управления индикаторами
void indControl(ind_num_t num, ind_state_t state) {
    if (num < IND_NUM) {
        if (state & IND_RED_OFF)
            ind_state &= ~(IND_RED_ON << pos[num]);
        else if (state & IND_RED_ON)
            ind_state |= IND_RED_ON << pos[num];

        if (state & IND_GREEN_OFF)
            ind_state &= ~(IND_GREEN_ON << pos[num]);
        else if (state & IND_GREEN_ON)
            ind_state |= IND_GREEN_ON << pos[num];

        led_inds <: ind_state;

        debug_printf("IND Set %x %x %x %x\n", ind_state>>pos[0] & 3, ind_state>>pos[1] & 3, ind_state>>pos[2] & 3, ind_state>>pos[3] & 3);
    }
    else
        debug_printf("IND Set num ERROR\n");
}

// Функция возвращает текущее состояние индикатора
ind_state_t indCheck(ind_num_t num) {
    if (num < IND_NUM) {
        unsigned state;

        state = (ind_state >> pos[num]) & 3;
        state |= ~(state << 2) & (3<<2); // не используется

        debug_printf("IND Get %x %x\n", num, state);
        return state;
    }
    else {
        debug_printf("IND Get num ERROR\n");
        return 0;
    }
}
