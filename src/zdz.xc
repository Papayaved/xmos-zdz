/*
 * плата версии v2
 * XEF216-512-TQ128-I20 24MHz
 *
 */

#include <platform.h>
#include "all_libs.h"
#include "defines.h"
#include "my_types.h"

#include "ports.h"

#include "adc.h"
#include "sensor_task.h"
#include "led_task.h"

#include "tile0_task.h"

#include "app_task.h"

#include "clock_task.h"
#include "eth_task.h"
#include "osc_task.h"
#include "flash.h"

// Программный сброс
void soft_reset0() {
    unsigned id;
    const unsigned addr = 6;
    unsigned reg;

    id = get_tile_id(tile[1]);
    read_sswitch_reg(id, addr, reg);
    write_sswitch_reg_no_ack(id, addr, reg & ~(1U<<31));

    id = get_local_tile_id();
    read_sswitch_reg(id, addr, reg);
    write_sswitch_reg_no_ack(id, addr, reg & ~(1U<<31));
}

// конфигурирвоание переферии
void configure0() {
    debug_printf("configure0\n");

    // сброс микросхемы физического уровня Ethernet
    phyReset <: 0;

    // Настройка частот АЦП
    configure_clock_rate_at_least(clkBlk, 100, 16); // 100/16 = 6.25 MHz
    configure_port_clock_output(adcClk, clkBlk);
    configure_in_port(adcIn_1, clkBlk);
    configure_in_port(adcIn_2, clkBlk);
    configure_in_port(adcIn_3, clkBlk);

    configure_out_port(ledWork, clkBlk, TEST_LED_OFF);
    configure_out_port(ledTest, clkBlk, TEST_LED_OFF);

    start_clock(clkBlk);

    delay_milliseconds(1);

    // убрали сброс
    phyReset <: 1;

    debug_printf("configure0 FIN\n");
}

int main() {
    streaming chan ch_adc[ADC_NUM];
    application_if i_app[ADC_NUM];
    tile0_resources_if i_t0;
    tile0_switches_if i_sw[2];
    clock_if i_clock;
    goose_if i_g;

    osc_if i_osc[ADC_NUM];
    osc_eth_if i_osc_eth;

    ethernet_cfg_if i_cfg[1];
    ethernet_rx_if i_rx[1];
    ethernet_tx_if i_tx[1];
    smi_if i_smi;

    led_if i_led[ADC_NUM];

    chan c_param;

    par {
        on tile[0] : {
            relays <: RELAY_DEFAULT;
            wdt_reset0();

            debug_printf("ver: 0x%x\n", SOFT_VER);
            configure0();
            wdt_reset0();

            InitChannels0();
            wdt_reset0();

            factory_t factory;
            sens_param_t param;
            {
                ReadFactory0(&factory, &param);

                wdt_reset0();

                c_param <: param.up;
                c_param <: param.dur;
                c_param <: param.sat;
                c_param <: param.sat_len;

                wdt_reset0();
            }

            par {
                tile0_task(i_t0, i_sw);

                eth_task0(factory, param, i_cfg[0], i_rx[0], i_tx[0], i_smi, i_clock, i_g, i_sw[1], i_osc_eth);

                app_task(i_app, ADC_NUM, i_t0, i_g);

                led_task0(i_led, i_sw[0]);
                sinc3(adcIn_1, ch_adc[CH_1]);
                sinc3(adcIn_2, ch_adc[CH_2]);
                sinc3(adcIn_3, ch_adc[CH_3]);
            }
        }
        on tile[1] : {
            sens_param_t param;

            c_param :> param.up;
            c_param :> param.dur;
            c_param :> param.sat;
            c_param :> param.sat_len;

//            debug_printf("Tile 1 param: up %d, dur %d, sat %d, sat_len %d\n",\
//                    param.up, param.dur, param.sat, param.sat_len);

            par {
                clock_task(i_clock);

                smi(i_smi, p_smi_mdio, p_smi_mdc);

                mii_ethernet_mac(i_cfg, 1, i_rx, 1, i_tx, 1,
                    p_eth_rxclk, p_eth_rxerr, p_eth_rxd, p_eth_rxdv, p_eth_txclk, p_eth_txen,
                    p_eth_txd, p_eth_timing, eth_rxclk, eth_txclk, ETHERNET_BUFSIZE);

                OscTask(i_osc, ADC_NUM, i_osc_eth);

                sensor_task(CH_1, param, ch_adc[CH_1], i_app[CH_1], i_osc[CH_1], i_led[CH_1]);
                sensor_task(CH_2, param, ch_adc[CH_2], i_app[CH_2], i_osc[CH_2], i_led[CH_2]);
                sensor_task(CH_3, param, ch_adc[CH_3], i_app[CH_3], i_osc[CH_3], i_led[CH_3]);
            }
        }
    }
    return 0;
}
