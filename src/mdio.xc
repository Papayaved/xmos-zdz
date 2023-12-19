#include <debug_print.h>

#include "mdio.h"
#include "defines.h"

// Функция проверки подключения Ethernet кабеля
BOOL isPhyLink(client smi_if i_smi) {
    BOOL powOK, linkOK;
    powOK = smi_phy_is_powered_down(i_smi, ETHERNET_SMI_PHY_ADDRESS) == 0;

    if (powOK)
        linkOK = smi_get_link_state(i_smi, ETHERNET_SMI_PHY_ADDRESS) == ETHERNET_LINK_UP;
    else
        linkOK = 0;

    return linkOK;
}

// Функция проверка наличия микросхемы физического уровня Ethernet
BOOL TestMDIO(client smi_if i_smi) {
    static unsigned phy_id;
    unsigned tmp_id;
    BOOL OK;

    if (!phy_id)
        for (int i = 0; i < 10; i++) { // 10 попыток
            phy_id = smi_get_id(i_smi, ETHERNET_SMI_PHY_ADDRESS);
            delay_milliseconds(10); // пауза
            tmp_id = smi_get_id(i_smi, ETHERNET_SMI_PHY_ADDRESS);

            OK = phy_id != 0 && ~phy_id != 0 && phy_id == tmp_id;
            if (OK) break;
        }
    else { // быстрая повторная проверка
        tmp_id = smi_get_id(i_smi, ETHERNET_SMI_PHY_ADDRESS);
        OK = phy_id != 0 && ~phy_id != 0 && phy_id == tmp_id;
    }

    if (OK)
        debug_printf("Phy ID: %08x\n", phy_id);
    else
        debug_printf("Read Phy ID error\n");

    return OK;
}
