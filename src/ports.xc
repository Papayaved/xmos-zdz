/* Порты процессора */

#include <platform.h>

// Последовательные данные с АЦП
in buffered port:32 adcIn_1 = T0_IN_1;
in buffered port:32 adcIn_2 = T0_IN_2;
in buffered port:32 adcIn_3 = T0_IN_3;
// Частота на АЦП
out port adcClk = T0_ADC_CLK;
// внутреняя частота
clock clkBlk = on tile[0] : XS1_CLKBLK_1;

// Порты PHY DP83640TVV
port p_eth_rxclk  = T1_PHY_RXCLK;
port p_eth_rxd    = T1_PHY_RXD;
port p_eth_txd    = T1_PHY_TXD;
port p_eth_rxdv   = T1_PHY_RXDV;
port p_eth_txen   = T1_PHY_TXEN;
port p_eth_txclk  = T1_PHY_TXCLK;
port p_eth_rxerr  = T1_PHY_RXERR;
port p_eth_timing = on tile[1] : XS1_PORT_8B;

clock eth_rxclk   = on tile[1] : XS1_CLKBLK_1;
clock eth_txclk   = on tile[1] : XS1_CLKBLK_2;

// Порты MDIO
port p_smi_mdio = T1_PHY_MDIO;
port p_smi_mdc  = T1_PHY_MDC;

// Сброс микросхемы физического уровня Ethernet
out port phyReset = T0_PHY_RESET;

// Сброс внешнего watchdog таймера
out port wd = T0_WATCHDOG;

// Реле
out port relays = T0_RELAYS;

// Переключатели выбора режима работы
in port switches = T0_SWITCHES;

// Светодиоды тестового сигнала
out port ledTest = T0_LED_TEST;
out port ledWork = T0_LED_WORK;

// Светодиоды индикации
out port led_inds = T0_LEDS;
