#include "eth_task.h"
#include "l_eth_task.h"
#include "rx_cont.h"
#include "flash.h"
#include "buffer.h"

uint64_t my_mac; // MAC адрес устройства
uint8_t model[VISIBLE_STRING_LENGTH]; // model name "OrionZDZ", null terminated
uint8_t sn[VISIBLE_STRING_LENGTH]; // serial number, null terminated
sens_param_t l_param;

uint64_t remote_mac = MAC_BROADCAST; // MAC адрес удаленного устройства
uint32_t my_ip; // IP адрес устройства
uint32_t remote_ip = IP_BROADCAST; // IP адрес удаленного устройства
uint16_t my_port = DEFAULT_MY_PORT; // UDP порт устройства
uint16_t remote_port = DEFAULT_REMOTE_PORT; // UDP порт удаленного устройства
BOOL goose_ena = TRUE; // штатные GOOSE сообщения включены
BOOL goose_req; // флаг запроса изменения параметров GOOSE
BOOL arp_req; // запрос включения ARP
BOOL soft_rst_req; // запрос програмного сброса параметров GOOSE

Settings set = {DEFAULT_T_MIN, DEFAULT_T_MAX}; // настройки GOOSE
OscSettings osc_set; // cтруктура с параметрами работы осцилографа

static unsigned stNum = 1, sqNum; // переменные GOOSE
static unsigned T_cur = DEFAULT_T_MAX; // текущий период GOOSE сообщений

static BOOL phy_ena; // микросхема физического уровня Ethernet найдена
static BOOL link_OK; // Ethernet кабель подключен

// Локальная функция инициализации контроллера Ethernet
static void EtherInit0(client ethernet_cfg_if i_cfg, client ethernet_rx_if i_rx, client smi_if i_smi, client clock_if i_clock);

// Копия текущего состояния устройства в задаче eth_task
static GOOSE_BITS flags = NO_FLAGS_BIT;

// Функция записи текущих значений в штатный GOOSE пакет
static void SetGoose(uint32_t T_sec) {
    SetTimeAllowedToLive(main_goose, 3 * T_cur);
    SetT(main_goose, T_sec, 0, 1<<7 | 1<<5);
    SetStNum(main_goose, stNum);
    SetSqNum(main_goose, sqNum++);

    if (sqNum == 0) sqNum = 1;

    SetEnumerated(main_goose, flags & TEST_BIT ? 3 : 1);
    SetBoolean(main_goose, flags);
}

// Задача обслуживающая приём и передачу данных по сети
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
) {
    debug_printf("Eth_tsk0\n");

    memcpy((uint8_t*)&my_mac, factory.mac, MACADDR_NUM_BYTES);
    memcpy(model, factory.model, VISIBLE_STRING_LENGTH);
    memcpy(sn, factory.sn, VISIBLE_STRING_LENGTH);

    memcpy(&l_param, &param, sizeof(sens_param_t));

    GooseInit0(TRUE); // чтение шаблона GOOSE пакета и настроек из flash памяти
    EtherInit0(i_cfg, i_rx, i_smi, i_clock); // инициализация Ethernet контроллера

    // инициализация осциллографа
    osc_set.trig_ff = 0; // осциллограф отключен
    osc_set.startPos = 16;
    i_osc_eth.run(osc_set);

    flags = i_g.get_flags(); // ждем основную задачу

    while (1) {
        [[ordered]]
        select {
        case i_rx.packet_ready(): // обработчик приема Ethernet пакетов
            ethernet_packet_info_t rx_info;

            exception_t exception;
            TRY { // должен перехватывать аппаратные исключения
                i_rx.get_packet(rx_info, rx_goose.data, MTU); // чтение данных в приемный буфер
                rx_controller(rx_info, i_tx, i_sw, i_osc_eth); // обработка принятого пакета и формирование ответа
            }
            CATCH(exception) {
                debug_printf("Unexpected exception: type=%d data=%d\n",
                        exception.type, exception.data);
            }

            if (soft_rst_req) { // запрос обновления GOOSE пакета (часть сброса)
                soft_rst_req = FALSE;
                debug_printf("RST Link Up\n");

                flags = i_g.get_flags();
                T_cur = set.T_max;
                i_clock.setGooseAlarm(T_cur);
            }

            if (goose_req) { // вкл/выкл штатный GOOSE
                goose_req = FALSE;

                if (goose_ena) {
                    flags = i_g.get_flags();
                    T_cur = set.T_max;
                    i_clock.setGooseAlarm(T_cur);
                }
                else
                    i_clock.setGooseAlarm(0);

                debug_printf("goose_ena: %x\n", goose_ena);
            }

            if (arp_req) { // запрос включения ARP
                arp_req = FALSE;
                SendARPAnnounce(i_tx, my_mac);
                SendARPReq(i_tx, my_mac, remote_ip);
            }

            break;

        case i_g.goose_rdy(): // обработчик событий от основной задачи main_task
#ifdef ETH_DEBUG
            debug_printf("Send %x...\n", flags);
#endif
            flags = i_g.get_flags();

            stNum++; // номер запроса
            if (stNum == 0) stNum = 1;

            sqNum = 0; // новая серия пакетов
            SetGoose(i_clock.getSeconds());

            if (goose_ena && link_OK) { // формирование штатного GOOSE пакета по событию
                i_tx.send_packet(main_goose.data, main_goose.length, ETHERNET_ALL_INTERFACES); // blocking
#ifdef ETH_DEBUG
                debug_printf("Sent\n");
#endif
            }

            T_cur = set.T_min; // максимальная частота
            i_clock.setGooseAlarm(T_cur);

            break;

        case i_clock.Alarm(): // обработчик событий от таймеров
            AlarmFlags ff = i_clock.AlarmType();

            if (ff & GOOSE_ALARM) { // формирование штатного GOOSE пакета по времени
#ifdef ETH_DEBUG
                debug_printf("Goose Alarm: ");
#endif
                if (link_OK && T_cur >= set.T_max) {
                    link_OK = phy_ena ? isPhyLink(i_smi) : FALSE; // check link

                    if (!link_OK) {
                        i_clock.LinkEna(TRUE); // включение таймера опроса состояния сети
                        debug_printf("LINK DOWN\n");
                    }
                }

                SetGoose(i_clock.getSeconds());

                if (goose_ena && link_OK) {
                    i_tx.send_packet(main_goose.data, main_goose.length, ETHERNET_ALL_INTERFACES);
#ifdef ETH_DEBUG
                    debug_printf("Sent\n");
#endif
                }

                i_clock.setGooseAlarm(T_cur);

                if (T_cur < set.T_max) {
                    T_cur <<= 1; // увеличение периода в 2 раза
                    if (T_cur > set.T_max) T_cur = set.T_max;
                }
            }

            if (ff & LINK_ALARM) { // опрос микросхемы физического уровня о наличии подключения
#ifdef ETH_DEBUG
                debug_printf("Link Alarm\n");
#endif
                link_OK = phy_ena ? isPhyLink(i_smi) : FALSE;

                if (link_OK) {
                    debug_printf("LINK UP\n");
                    i_clock.LinkEna(FALSE); // отключение таймера

                    flags = i_g.get_flags();

                    T_cur = set.T_max;
                    i_clock.setGooseAlarm(T_cur);
                }
            }

            if ((ff & CLOCK_ALARM) && link_OK) { // раз в секунду посылка ARP пакетов для поддержания таблицы IP адресов на ПК
                //TestUdp(i_tx, t);
                if (my_ip != 0 && my_ip != IP_BROADCAST && remote_ip != 0 && remote_ip != IP_BROADCAST)
                    SendARPReq2(i_tx); // посылка одноадресного ARP запроса к ПК
            }

            break;

        case i_osc_eth.osc_ready(): // обработчик готовности данных задачи осциллографа
            GooseObject& o = osc_packet.obj.octet_str;

            for (unsigned i = 0; i < ADC_NUM; i++) { // посылка 3х пакетов с осциллограмами
/* todo: можно добавить не большую паузу на таймере на время отправки пакета или не сбрасывать notification,
 *       чтобы задача не блокировалась на долго и более приоритетные события могли обработаться
 */
                uint32_t sqNum = GetSqNum(osc_packet);
                SetSqNum(osc_packet, ++sqNum);

                osc_packet.data[o.startIndex] = 0xff; // func
                osc_packet.data[o.startIndex + 4] = i; // номер АЦП

                i_osc_eth.get_data(i, o.startIndex + 8, osc_packet.data, o.startIndex + o.length);
                i_tx.send_packet(osc_packet.data, osc_packet.length, ETHERNET_ALL_INTERFACES);
            }

            break;
        }
    }
}

// Внутренняя функция чтения шаблона параметров работы из Flash памяти
void GooseInit0(BOOL print_ena) {
    debug_printf("Goose init called\n");
    // Reset
    stNum = 1;
    sqNum = 0;
    T_cur = DEFAULT_T_MAX;

    ReadSettings0(print_ena); // чтения параметров из Flash памяти

    // Инициализация штатного GOOSE пакета постоянными значениями
    SetSrcMac(main_goose, my_mac); // запись Ethernet адреса устройства
    SetModel(main_goose, model, VISIBLE_STRING_LENGTH); // запись названия устройства
    SetSN(main_goose, sn, VISIBLE_STRING_LENGTH); // запись серийного номера устройства
    SetVersion(main_goose, SOFT_VER); // запись версии программы

    debug_printf("MAC: %x_%x_%x_%x_%x_%x\n",\
            (uint8_t)(my_mac>>40), (uint8_t)(my_mac>>32), (uint8_t)(my_mac>>24),
            (uint8_t)(my_mac>>16), (uint8_t)(my_mac>>8), (uint8_t)my_mac);

    debug_printf("Model: ");
    for (int i = 0; i < VISIBLE_STRING_LENGTH && model[i] != 0; i++)
        debug_printf("%c", model[i]);

    debug_printf("\n");

    debug_printf("SN: ");
    for (int i = 0; i < VISIBLE_STRING_LENGTH && sn[i] != 0; i++)
        debug_printf("%c", sn[i]);

    debug_printf("\n");
}

// Локальная функция инициализации контроллера Ethernet
static void EtherInit0(
        client ethernet_cfg_if i_cfg,
        client ethernet_rx_if i_rx,
        client smi_if i_smi,
        client clock_if i_clock)
{
    ethernet_macaddr_filter_t filter;
    size_t index = i_rx.get_index();

    // Запись в фильтр Ethernet адреса устройства
    const uint8_t* const p_mac = (uint8_t*)&my_mac;
    filter.appdata = MY_MAC_INDEX;
    for (int i = 0, j = MACADDR_NUM_BYTES - 1; i < MACADDR_NUM_BYTES; i++, j--)
        filter.addr[i] = p_mac[j];

    i_cfg.add_macaddr_filter(index, 0, filter);

    // Add Ethernet broadcast address
    filter.appdata = BROADCAST_MAC_INDEX;
    memset(filter.addr, 0xff, MACADDR_NUM_BYTES);
    i_cfg.add_macaddr_filter(index, 0, filter);

    link_OK = FALSE; // начальное состояние - нет подключения

    phy_ena = TestMDIO(i_smi); // тестирование MDIO интерфейса микросхемы физического уровня

    if (phy_ena) {
        // настройка микросхемы физического уровня
        smi_configure(i_smi, ETHERNET_SMI_PHY_ADDRESS, LINK_100_MBPS_FULL_DUPLEX, SMI_ENABLE_AUTONEG);
        i_clock.LinkEna(TRUE);
#ifdef ETH_DEBUG
        debug_printf("PHY enabled\n");
#endif
    }
    else {
#ifdef ETH_DEBUG
        debug_printf("PHY not found\n");
#endif
    }
}
