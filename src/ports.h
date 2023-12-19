/* Порты процессора */

#ifndef PORTS_H_
#define PORTS_H_

// Порты АЦП
extern in buffered port:32 adcIn_1;
extern in buffered port:32 adcIn_2;
extern in buffered port:32 adcIn_3;
extern out port adcClk;
extern clock clkBlk;

// Порты PHY DP83640TVV
extern port p_eth_rxclk, p_eth_rxd, p_eth_txd, p_eth_rxdv, p_eth_txen, p_eth_txclk, p_eth_rxerr, p_eth_timing;

extern port p_smi_mdio, p_smi_mdc;

extern out port phyReset;
extern out port wd;

extern clock eth_rxclk, eth_txclk;

// Реле
extern out port relays;

// Переключатели выбора режима работы
extern in port switches;

// Светодиоды тестового сигнала
extern out port ledTest;
extern out port ledWork;

extern out port led_inds;

#endif /* PORTS_H_ */
