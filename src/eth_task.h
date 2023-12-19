#ifndef ETH_TSK_H_
#define ETH_TSK_H_

#include <stdio.h>
#include <xs1.h>
#include <timer.h>

#include <ethernet.h>
#include <mii.h>
#include <smi.h>

#include <string.h>
#include <print.h>
#include <trycatch.h>
#include <debug_print.h>

#include "clock_task.h"
#include "mdio.h"

#include "goose.h"
#include "tile0_task.h"
#include "osc_task.h"

#include "flash.h"

//#define ETH_DEBUG // отладка Ethernet

#define DEFAULT_MY_PORT (60000) // UDP порт приёма данных и порт источника данных устройства
#define DEFAULT_REMOTE_PORT (60001) // UDP порт назначения данных (входящий порт ПК)

/* Задача обслуживающая прием и передачу данных по сети
 * Должна быть запущена на tile0 поскольку общается с flash памятью микроконтроллера напрямую
 * factory      MAC адрес, модель и серийный номер
 * param        параметры работы датчика
 * i_cfg        интерфейс конфигурирования Ethernet контроллера
 * i_rx         интерфейс приёма данных
 * i_tx         интерфейс передачи данных
 * i_smi        интерфейс с микросхемой физического уровня Ethernet
 * i_clock      интерфейс с задачей таймеров clock_task
 * i_g          интерфейс с задачей main_task
 * i_sw         интерфейс чтения положения DIP переключателей
 * i_osc_eth    интерфейс с задачей осцилографа
 */
//[[combinable]]
void eth_task0(
    const factory_t& factory,
    const sens_param_t& param,
    client ethernet_cfg_if i_cfg,
    client ethernet_rx_if i_rx,
    client ethernet_tx_if i_tx,
    client smi_if i_smi,
    client clock_if i_clock,
    client goose_if i_g,
    client tile0_switches_if i_sw,
    client osc_eth_if i_osc_eth
);

#endif /* ETH_TSK_H_ */
