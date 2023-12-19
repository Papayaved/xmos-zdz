#include "rx_cont.h"
#include "aux_func.h"
#include "eth_task.h"
#include "l_eth_task.h"
#include "buffer.h"

// Локальные функции см. ниже
static void udp_parser(
        unsigned len,
        client ethernet_tx_if i_tx,
        client tile0_switches_if i_sw,
        client osc_eth_if i_osc_eth);

static void arp_parser(unsigned len, client ethernet_tx_if i_tx);

static void goose_parser(
        unsigned len,
        client ethernet_tx_if i_tx,
        client tile0_switches_if i_sw,
        client osc_eth_if i_osc_eth);

static void data_parser(
        int data_size, int tx_start_pos,
        client tile0_switches_if i_sw,
        PacketType packet_type,
        client ethernet_tx_if i_tx,
        client osc_eth_if i_osc_eth);

static void EtherReset();

// Основная функция обработки входящих сообщений и формирования ответов
void rx_controller(
        const ethernet_packet_info_t rx_info,
        client ethernet_tx_if i_tx,
        client tile0_switches_if i_sw,
        client osc_eth_if i_osc_eth)
{
    MAC_INDEX rx_mac_index = (MAC_INDEX)rx_info.filter_data;
//    debug_printf("Got packet\n");

    if (rx_info.type == ETH_DATA && rx_info.len >= 42 + 12 && rx_info.len <= MTU) {
        uint16_t ethType = EthType(rx_goose.data);
//        debug_printf("ethType: %x\n", ethType);

        switch ((ETHERTYPE)ethType) {
        case ETHERTYPE_IP:
            udp_parser(rx_info.len, i_tx, i_sw, i_osc_eth);
            break;
        case ETHERTYPE_ARP:
            arp_parser(rx_info.len, i_tx);
            break;
        case ETHERTYPE_GOOSE: case ETHERTYPE_VLAN:
            if (rx_mac_index == MY_MAC_INDEX)
                goose_parser(rx_info.len, i_tx, i_sw, i_osc_eth);
            break;
        }
    }
}

// парсер udp пакета
static void udp_parser(
        unsigned len,
        client ethernet_tx_if i_tx,
        client tile0_switches_if i_sw,
        client osc_eth_if i_osc_eth)
{
    uint8_t (& rx_buf)[MTU] = rx_goose.data;

    uint8_t ipVer = IPVer(rx_buf);
    uint8_t hLen = IPHeaderLen(rx_buf);
    uint8_t protocol = Protocol(rx_buf);
    uint32_t dstIP = DstIP(rx_buf);
    uint16_t dstPort = DstPort(rx_buf);

//    uint64_t dstMac = DstMac(rx_buf);
//        debug_printf("RxLen: %d DstMAC: %x_%x\n", len, (int)(dstMac>>32), (int)dstMac);
//        debug_printf("ipVer: %x hLen: %x protocol: %x\n", ipVer, hLen, protocol);

    if (ipVer == 4 && hLen == 5 && protocol == IP_UDP) {
//            debug_printf("dstIP: %x dstPort: %d my_port: %d\n", dstIP, dstPort, my_port);

        if (dstPort == my_port && (dstIP == IP_BROADCAST || (my_ip != 0 && dstIP == my_ip))) {
//              PrintByteArray(rx_buf, len);
            uint16_t data_size = Length(rx_buf) - 8;
            debug_printf("CMD size: %d\n", data_size);

            if (data_size >= 12) {
                init_rx_buf(42);
                uint64_t addr = read_uint64();
//                  debug_printf(" addr: %x_%x my: %x_%x", (int)(addr>>32), (int)addr, (int)(my_mac>>32), (int)my_mac);

                if (addr == my_mac) {
                    remote_mac = SrcMac(rx_buf);
                    remote_ip = SrcIP(rx_buf);

                    data_parser(data_size - 8, 42 + 8, i_sw, UDP_PACKET, i_tx, i_osc_eth);
                }
            }
        }
    }
}

// парсер GOOSE пакета
static void goose_parser(
        unsigned len,
        client ethernet_tx_if i_tx,
        client tile0_switches_if i_sw,
        client osc_eth_if i_osc_eth)
{
    rx_goose.length = 0;

    BOOL OK = ParseGoose(rx_goose, len, FALSE);
    GooseObject& data = rx_goose.obj.octet_str;

    if (OK && data.length != 0) {
        remote_mac = SrcMac(rx_goose.data);
        init_rx_buf(data.startIndex);
        data_parser(data.length, 0, i_sw, GOOSE_PACKET, i_tx, i_osc_eth);
    }

    rx_goose.length = 0;
}

static void write_udp_header(
        int& tx_it,
        uint64_t my_mac, uint64_t dst_mac,
        uint32_t my_ip, uint32_t dst_ip,
        uint16_t my_port, uint16_t dst_port);

// посылка пакета udp
void udp_send(client ethernet_tx_if i_tx) {
    int it = get_tx_pos();

    if (my_ip != 0)
        write_udp_header(it, my_mac, remote_mac, my_ip, remote_ip, my_port, remote_port);
    else
        write_udp_header(it, my_mac, MAC_BROADCAST, my_ip, IP_BROADCAST, my_port, remote_port);

    // add padding if need for minimum Ethernet packet length 64
    while (it < 60) tx_buf[it++] = 0;

    i_tx.send_packet(tx_buf, it, ETHERNET_ALL_INTERFACES);
}

// посылка пакета GOOSE
void goose_send(client ethernet_tx_if i_tx) {
    static uint8_t tx_goose[MTU];

    int tx_len = GenerateGoose(rx_goose, tx_buf, get_tx_pos(), tx_goose);

    i_tx.send_packet(tx_goose, tx_len, ETHERNET_ALL_INTERFACES);
}

static BOOL bUpgrade; // идет обновление прошики

// разбор полученных данных и формирование ответа
static void data_parser(
        int data_size,
        int tx_start_pos,
        client tile0_switches_if i_sw,
        PacketType packet_type,
        client ethernet_tx_if i_tx,
        client osc_eth_if i_osc_eth)
{
    static uint32_t test_reg = 0x12345678; // тестовый регистр
    static unsigned page_num_old = ~0U; // номер прошлой страницы flash

    static fl_BootImageInfo bootImageInfo; // структура описывающая образ программы

    uint32_t func; // функция комманды
    BOOL func_OK; // результат выполнения функции

    init_tx_buf(tx_start_pos); // инициализация индекса начала данных в буфере на передачу

    func = read_uint32(); // чтение данных из входного буфера
    debug_printf("func: %x\n", func);

    add_uint32(func); // запись данных в буфер передачи

    switch(func) {
    case 0: // mount - функция монтирования flash - устаревшая
        if (data_size == sizeof(uint32_t)) {
//            bMount = fl_connectToDevice(flashPorts, flashSpecs, FLASH_SPECS_LEN) == 0;
//
//            if (bMount)
//                if (fl_getPageSize() > FLASH_BUFFER_SIZE) {
//                    bMount = FALSE;
//                    fl_disconnect();
//                    debug_printf("ERROR: flash page size is too small\n");
//                }
//                else
//                    debug_printf("Mounted\n");
//            else
//                debug_printf("ERROR: @mount\n");

            add_uint32(1);
            switch (packet_type) {
            case UDP_PACKET: udp_send(i_tx); break;
            case GOOSE_PACKET: goose_send(i_tx); break;
            }
        }
        break;
    case 1: // dismount - функция размонтирования flash - устаревшая
        if (data_size == sizeof(uint32_t)) {
//            if (bMount) {
//                func_OK = fl_disconnect() == 0;
//                if (func_OK) {
//                    bMount = FALSE;
//                    debug_printf("Dismounted\n");
//                }
//                else
//                    debug_printf("ERROR: @dismount\n");
//            }
//            else
//                func_OK = FALSE;

            add_uint32(1);

            switch (packet_type) {
            case UDP_PACKET: udp_send(i_tx); break;
            case GOOSE_PACKET: goose_send(i_tx); break;
            }
        }
        break;
    case 2: // read param
        if (data_size == sizeof(uint32_t)) {
            if (bUpgrade) // защита
                bUpgrade = fl_disconnect() != 0; // отключение flash

            BOOL bMount = !bUpgrade && fl_connectToDevice(flashPorts, flashSpecs, FLASH_SPECS_LEN) == 0; // подключение flash
            add_uint32(bMount); // func_OK

            if (bMount) {
                // Data info
                add_uint32(fl_getPageSize());
                add_uint32(fl_getNumDataPages());
                add_uint32(fl_getDataSectorSize(1));
                add_uint32(fl_getNumDataSectors());
                add_uint32(fl_getFlashSize());
                add_uint32(fl_getDataPartitionSize());
                add_uint32(SOFT_VER);

                // Image info
                if (fl_getFactoryImage(bootImageInfo) == 0) {
                    add_uint32(bootImageInfo.factory);
                    add_uint32(bootImageInfo.size);
                    add_uint32(bootImageInfo.startAddress);
                    add_uint32(bootImageInfo.version);

                    if (fl_getNextBootImage(bootImageInfo) == 0) {
                        add_uint32(bootImageInfo.factory);
                        add_uint32(bootImageInfo.size);
                        add_uint32(bootImageInfo.startAddress);
                        add_uint32(bootImageInfo.version);
                    }
                }

                fl_disconnect(); // отключение flash
            }
            else
                debug_printf("Not mount\n");

            switch (packet_type) { // указатели на функцию в xC отсутствуют
            case UDP_PACKET: udp_send(i_tx); break;
            case GOOSE_PACKET: goose_send(i_tx); break;
            }
        }
        break;
    case 3: // read data page
        if (data_size == 2 * sizeof(uint32_t)) {
            if (bUpgrade)
                bUpgrade = fl_disconnect() != 0;

            BOOL bMount = !bUpgrade && fl_connectToDevice(flashPorts, flashSpecs, FLASH_SPECS_LEN) == 0;
            uint32_t page_num = read_uint32();

            if (bMount) {
                func_OK = fl_readDataPage(page_num, page) == 0; // todo: write direct to tx buffer
                add_uint32(func_OK);
                if (func_OK) add_uint32(page_num);

                uint32_t page_size = fl_getPageSize();

                if (func_OK) add_range(page, page_size);

                fl_disconnect();
                debug_printf("page_num %d\n", page_num);
            }
            else {
                debug_printf("Not mount\n");
                add_uint32(0);
            }


            switch (packet_type) {
            case UDP_PACKET: udp_send(i_tx); break;
            case GOOSE_PACKET: goose_send(i_tx); break;
            }
        }
        break;
    case 4: // write page
        if (data_size >= 3 * sizeof(uint32_t)) {
            uint32_t page_num;

            if (bUpgrade)
                bUpgrade = fl_disconnect() != 0;

            BOOL bMount = !bUpgrade && fl_connectToDevice(flashPorts, flashSpecs, FLASH_SPECS_LEN) == 0;

            if (bMount) {
                unsigned page_size = fl_getPageSize();
                unsigned sect_size = fl_getDataSectorSize(1);
                unsigned pages_in_sect = sect_size / page_size;

                if (data_size == 2 * sizeof(uint32_t) + page_size) { // write only by full pages
                    page_num = read_uint32(); // page number

                    if (page_num % pages_in_sect == 0) {
                        unsigned sect = page_num / pages_in_sect;
                        if (sect != 0) {
                            debug_printf("Erase sector %d\n", sect);
                            fl_eraseDataSector(sect);
                        }
                        else
                            debug_printf("ERROR: Attempt to write to sector 0\n");
                    }

                    debug_printf("Write page %d...", page_num);
//                    read_range(page, page_size);
//                    func_OK = fl_writeDataPage(page_num, page) == 0; // todo: read direct from rx buffer
                    func_OK = fl_writeDataPage(page_num, get_read_ptr()) == 0;

                    if (func_OK)
                        debug_printf("OK\n");
                    else
                        debug_printf("ERROR\n");
                }
                else {
                    debug_printf("Packet size ERROR %d\n", data_size);
                    func_OK = FALSE;
                }

                fl_disconnect();
            }
            else {
                debug_printf("Not mount\n");
                func_OK = FALSE;
            }

            add_uint32(func_OK);
            if (func_OK) add_uint32(page_num);

            switch (packet_type) {
            case UDP_PACKET: udp_send(i_tx); break;
            case GOOSE_PACKET: goose_send(i_tx); break;
            }
        }
        break;
    case 5: // read last image
        if (data_size == sizeof(uint32_t)) {
            if (bUpgrade)
                bUpgrade = fl_disconnect() != 0;

            BOOL bMount = !bUpgrade && fl_connectToDevice(flashPorts, flashSpecs, FLASH_SPECS_LEN) == 0;

            if (bMount) {
                uint32_t page_num = 0;
                func_OK = fl_getFactoryImage(bootImageInfo) == 0;
                fl_getNextBootImage(bootImageInfo);

                if (func_OK) {
                    unsigned image_size = bootImageInfo.size;
                    fl_startImageRead(bootImageInfo);
                    uint32_t page_size = fl_getPageSize();

                    do {
                        init_tx_buf(tx_start_pos);
                        add_uint32(func);

                        func_OK = fl_readImagePage(page) == 0;

                        if (func_OK) {
//                                            int remain;

                            if ((page_num + 1) * page_size >= image_size) {
                                add_uint32(2);
//                                                remain = image_size - page_num * page_size;
                                func_OK = FALSE;
                            }
                            else {
                                add_uint32(1);
//                                                remain = page_size;
                            }

                            add_uint32(page_num++);
                            add_range(page, page_size);
                        }
                        else { // error
                            add_uint32(2);
                            add_uint32(page_num);
                        }


                        switch (packet_type) {
                        case UDP_PACKET: udp_send(i_tx); break;
                        case GOOSE_PACKET: goose_send(i_tx); break;
                        }
                    } while (func_OK);

                    debug_printf("Read pages: %d\n", page_num);
                }
                else {
                    debug_printf("No image\n");
                    add_uint32(-1); // result
                    add_uint32(0); // page_num

                    switch (packet_type) {
                    case UDP_PACKET: udp_send(i_tx); break;
                    case GOOSE_PACKET: goose_send(i_tx); break;
                    }
                }

                fl_disconnect();
            }
            else {
                debug_printf("Not mount\n");
                add_uint32(0); // result
                add_uint32(0); // page_num

                switch (packet_type) {
                case UDP_PACKET: udp_send(i_tx); break;
                case GOOSE_PACKET: goose_send(i_tx); break;
                }
            }
        }
        break;
    case 6: // write page to upgrade image 0
        BOOL bMount;

        if (!bUpgrade)
            bMount = fl_connectToDevice(flashPorts, flashSpecs, FLASH_SPECS_LEN) == 0;
        else
            bMount = TRUE;

        unsigned pageNum = fl_getNumDataPages();
        unsigned page_size = fl_getPageSize();
        unsigned flashSize = fl_getFlashSize();

        unsigned dataSize = pageNum * page_size;
        unsigned bootSize = flashSize - dataSize;

//                        const unsigned maxsize = FLASH_MAX_UPGRADE_SIZE;
        if (data_size >= 3 * sizeof(uint32_t)) {
            uint32_t page_num = read_uint32();
            debug_printf("Write image page %d\n", page_num);
            func_OK = bMount && page_num == page_num_old;

            if (!bMount)
                debug_printf("Not mount\n");
            else if (func_OK)
                debug_printf("Skip rewrite page %d\n", page_num);
            else if (page_num != 0 && page_num != page_num_old + 1)
                debug_printf("Unexpected page %d, expected 0 or %d\n", page_num, page_num_old + 1);
            else if (bMount) {
                if (data_size == 2 * sizeof(uint32_t) + page_size) {
                    if (page_num == 0) {
                        func_OK = fl_getFactoryImage(bootImageInfo) == 0;
                        //unsigned maxsize = bootSize - bootImageInfo.size;
                        unsigned maxsize = bootSize>>1; // ?
                        debug_printf("Max image size: %d\n", maxsize);

                        if (func_OK) {
                            debug_printf("factory: %x size: %d startAddress: %x version: %x\n",\
                                    bootImageInfo.factory, bootImageInfo.size,\
                                    bootImageInfo.startAddress, bootImageInfo.version);

                            func_OK = fl_getNextBootImage(bootImageInfo) == 0;

                            if (func_OK) {
                                debug_printf("factory: %x size: %d startAddress: %x version: %x\n",\
                                        bootImageInfo.factory, bootImageInfo.size,\
                                        bootImageInfo.startAddress, bootImageInfo.version);

                                debug_printf("Replace image");
                                int res;
                                // fl_deleteImage // ??
                                do {
                                    res = fl_startImageReplace(bootImageInfo, maxsize);
                                    if (res > 0) {
                                        debug_printf(".");
                                        delay_milliseconds(100);
                                    }
                                    else if (res < 0)
                                        break;
                                } while (res != 0);

                                bUpgrade = res == 0;

                                if (bUpgrade)
                                    debug_printf("OK\n");
                                else
                                    debug_printf("Error\n");
                            }
                            else {
                                fl_getFactoryImage(bootImageInfo);

                                debug_printf("Add image");
                                int res;
                                do {
                                    res = fl_startImageAdd(bootImageInfo, maxsize, 0);
                                    if (res == 1) { // is not complite
                                        debug_printf(".");
                                        delay_milliseconds(100);
                                    }
                                    else if (res < 0)
                                        break;
                                } while (res != 0);

                                bUpgrade = res == 0;

                                if (bUpgrade)
                                    debug_printf("OK\n");
                                else
                                    debug_printf("Error\n");
                            }
                        }
                        else
                            debug_printf("No factory image\n");
                    }

                    if (bUpgrade) {
//                        read_range(page, page_size);
//                        func_OK = fl_writeImagePage(page) == 0;
                        func_OK = fl_writeImagePage(get_read_ptr()) == 0;
                    }
                    else
                        debug_printf("bUpgrade == FALSE\n");
                }
                else
                    debug_printf("Packet size error %d\n", data_size);

                debug_printf("page_num %d\n", page_num);

                if (!bUpgrade) {
                    fl_disconnect();
                    func_OK = FALSE;
                    page_num_old = ~0U;
                    debug_printf("No upgrage\n");
                }
            }

            add_uint32(func_OK);
            if (func_OK) {
                add_uint32(page_num);
                page_num_old = page_num;
            }

            switch (packet_type) {
            case UDP_PACKET: udp_send(i_tx); break;
            case GOOSE_PACKET: goose_send(i_tx); break;
            }
        }
        else
            debug_printf("size error %d\n", data_size);

        break;
    case 7: // end write image
        if (data_size == sizeof(uint32_t)) {
            func_OK = bUpgrade;

            if (bUpgrade) {
                int i = 0;
                BOOL err = FALSE;
                debug_printf("End image");
                while (fl_endWriteImage() != 0) {
                    debug_printf(".");
                    delay_milliseconds(100);
                    if (i++ >= 50) {
                        err = TRUE;
                        break;
                    }
                };

                if (!err)
                    debug_printf("OK\n");
                else
                    debug_printf("Wait flash ERROR\n");

                bUpgrade = FALSE;
                fl_disconnect();
            }
            else
                debug_printf("Not mount\n");

            add_uint32(func_OK);

            switch (packet_type) {
            case UDP_PACKET: udp_send(i_tx); break;
            case GOOSE_PACKET: goose_send(i_tx); break;
            }

            page_num_old = ~0U;
        }
        break;
    case 8: // delete all upgrade images
        if (data_size == sizeof(uint32_t)) {
            if (bUpgrade)
                bUpgrade = fl_disconnect() != 0;

            BOOL bMount = !bUpgrade && fl_connectToDevice(flashPorts, flashSpecs, FLASH_SPECS_LEN) == 0;

            int i = 0;
            if (bMount) {
                do {
                    func_OK = fl_getFactoryImage(bootImageInfo) == 0;
                    do {
                        func_OK = fl_getNextBootImage(bootImageInfo) == 0;
                    } while (func_OK);

                    if (bootImageInfo.factory == 0) {
                        fl_deleteImage(bootImageInfo);
                        i++;
                    }
                } while (bootImageInfo.factory == 0);

                fl_disconnect();
                debug_printf("Deleted %d images\n", i);
            }
            else
                debug_printf("Not mount\n");

            add_uint32(i);

            switch (packet_type) {
            case UDP_PACKET: udp_send(i_tx); break;
            case GOOSE_PACKET: goose_send(i_tx); break;
            }
        }
        break;

    case 0x10: // reg write
        if (data_size == 3 * sizeof(uint32_t)) {
            uint32_t wraddr = read_uint32();
            uint32_t wrdata = read_uint32();
            BOOL osc_req = FALSE;

            switch (wraddr) {
                case 0: test_reg = wrdata; break;
                case 1:
                    if (wrdata != 0) {
                        GooseInit0(FALSE);
                        soft_rst_req = TRUE;
                        goose_ena = TRUE;
                    }
                    break;

                case 6:
                    goose_req = TRUE;
                    goose_ena = wrdata != 0;
                    break;
                case 7:
                    if (wrdata & 1) EtherReset();
                    if (wrdata & 2) soft_reset0();
                    break;
                case 9:
                    if (osc_set.trig_ff != 0) {
                        osc_set.trig_ff = 0;
                        i_osc_eth.run(osc_set); // отключение осциллографа
                    }

                    osc_set.startPos = (uint16_t)wrdata;
                    osc_set.trig_ff = (uint8_t)(wrdata >> 16);
                    osc_req = osc_set.trig_ff != 0;
                    break;
            }

            add_uint32(1);
            add_uint32(wraddr);

            switch (packet_type) {
            case UDP_PACKET: udp_send(i_tx); break;
            case GOOSE_PACKET: goose_send(i_tx); break;
            }

            debug_printf("wraddr: %x d: %x\n", wraddr, wrdata);

            if (osc_req) {
                // Генерация пакета данных осциллографа на основе принятого пакета
                BOOL OK = GenerateGooseOsc(rx_goose, OSC_SIZE + 8, osc_packet);

                if (OK) {
                    SetSrcMac(osc_packet, my_mac); // запись Ethernet адреса устройства
                    SetDstMac(osc_packet, remote_mac); // запись Ethernet адреса ПК
                    i_osc_eth.run(osc_set);
                }
                else
                    osc_set.trig_ff = 0;
            }
        }
        break;
    case 0x11: // reg read
        if (data_size == 2 * sizeof(uint32_t)) {
            uint32_t rdaddr = read_uint32();
            uint32_t rddata;

            switch (rdaddr) {
                case 0: rddata = test_reg; break;

                case 2: rddata = SOFT_VER; break;
                case 3: rddata = my_ip; break;
                case 4: rddata = my_port; break;
                case 5: rddata = remote_port; break;
                case 6: rddata = goose_ena; break;

                case 8: rddata = i_sw.getSwitches(); break;
                case 9:
                    rddata = (uint32_t)osc_set.trig_ff << 16 | osc_set.startPos;
                    break;
                case 10:
                    rddata = l_param.up;
                    break;
                case 11:
                    rddata = l_param.dur;
                    break;
                case 12:
                    rddata = l_param.sat;
                    break;
                case 13:
                    rddata = l_param.sat_len;
                    break;
                default: rddata = 0; break;
            }

            add_uint32(1);
            add_uint32(rdaddr);
            add_uint32(rddata);

            switch (packet_type) {
            case UDP_PACKET: udp_send(i_tx); break;
            case GOOSE_PACKET: goose_send(i_tx); break;
            }

            debug_printf("rdaddr: %x q: %x\n", rdaddr, rddata);
        }
        break;
    case 0x12: // Set IP - for UDP protocol
        if (data_size >= 2 * sizeof(uint32_t)) {
            my_ip = read_uint32();
            arp_req = my_ip != 0 && my_ip != IP_BROADCAST;

            if (data_size >= 3 * sizeof(uint32_t)) {
                my_port = (uint16_t)read_uint32();

                if (data_size >= 4 * sizeof(uint32_t)) {
                    remote_port = (uint16_t)read_uint32();

                    if (data_size >= 5 * sizeof(uint32_t)) {
                        BOOL goose_ena_reg = goose_ena;
                        goose_ena = read_uint32() != 0;

                        if (goose_ena != goose_ena_reg) goose_req = TRUE;
//                                debug_printf("goose_ena: %x\n", goose_ena);
                    }
                }
            }

            debug_printf("my: %d.%d.%d.%d:%d remote: %d.%d.%d.%d:%d\n",
                    (uint8_t)(my_ip>>24), (uint8_t)(my_ip>>16), (uint8_t)(my_ip>>8), (uint8_t)(my_ip),
                    my_port,
                    (uint8_t)(remote_ip>>24), (uint8_t)(remote_ip>>16), (uint8_t)(remote_ip>>8), (uint8_t)(remote_ip),
                    remote_port);
        }
        break;
    }
}

static void EtherReset() {
    bUpgrade = FALSE;
    fl_disconnect();

//    arp_req = TRUE;
//    arp_ena = TRUE;
    my_ip = 0;
    remote_ip = IP_BROADCAST;
    remote_mac = MAC_BROADCAST;
    my_port = DEFAULT_MY_PORT;
    remote_port = DEFAULT_REMOTE_PORT;
    goose_req = !goose_ena;
    goose_ena = TRUE;

    osc_set.startPos = 16;
    osc_set.trig_ff = 0;

    soft_rst_req = TRUE;

    debug_printf("Eth param reseted");
}

// Local functions

const BOOL ECN = 0;
const uint16_t DSCP = 0;
const uint16_t IP_H_LEN = 5;
const uint16_t IP_VER = 4;
const uint16_t FRAGMENT_OFFSET = 0;
static uint16_t id;
const BOOL DF = 0;
const BOOL MF = 0;
const uint16_t TIME_TO_LIVE = 0x80;
const uint8_t protocol = IP_UDP;

static void udp_finalize(int& tx_it);

static void write_udp_header(
        int& tx_it,
        uint64_t my_mac, uint64_t dst_mac,
        uint32_t my_ip, uint32_t dst_ip,
        uint16_t my_port, uint16_t dst_port)
{
    write_byterev48(&tx_buf[0], dst_mac);
    write_byterev48(&tx_buf[6], my_mac);
    write_byterev16(&tx_buf[12], ETHERTYPE_IP);
    tx_buf[14] = IP_VER<<4 | IP_H_LEN;
    tx_buf[15] = DSCP<<2 | ECN;
    //write_byterev16(&tx_buf[16], total_len);
    write_byterev16(&tx_buf[18], id);
    tx_buf[20] = 0x40;
    tx_buf[21] = 0;
    tx_buf[22] = TIME_TO_LIVE; // time to life
    tx_buf[23] = protocol;
    //write_byterev16(&tx_buf[24], 0); // hchecksum
    write_byterev32(&tx_buf[26], my_ip); // src IP
    write_byterev32(&tx_buf[30], dst_ip);
    write_byterev16(&tx_buf[34], my_port); // src port
    write_byterev16(&tx_buf[36], dst_port);
    //write_byterev16(&tx_buf[38], length);
    //write_byterev16(&tx_buf[40], checksum);

    write64(&tx_buf[42], my_mac);

    udp_finalize(tx_it);
}

static void udp_finalize(int& tx_it) {
    uint16_t total_length = tx_it - 14;
    uint16_t length = tx_it - 42 + 8;

    write_byterev16(&tx_buf[16], total_length);
    write_byterev16(&tx_buf[24], 0); // hchecksum
    write_byterev16(&tx_buf[38], length);
    write_byterev16(&tx_buf[40], 0); // udp check sum

    // вычисление контрольной сумму IP заголовка
    uint32_t hchecksum = 0;
    for (int i = 14; i < 34; i += 2)
        hchecksum += (tx_buf[i]<<8) + tx_buf[i+1];

    id++;
//    hchecksum += IP_VER<<12 | IP_H_LEN<<8 | DSCP<<2 | ECN;
//    hchecksum += total_length;
//    hchecksum += id++;
//    hchecksum += MF<<15 | DF<<14 | 0<<13 | FRAGMENT_OFFSET;
//    hchecksum += TIME_TO_LIVE<<8 | protocol;
//    hchecksum += src_ip>>16;
//    hchecksum += src_ip & 0xffff;
//    hchecksum += l_dst_ip>>16;
//    hchecksum += l_dst_ip & 0xffff;
    hchecksum = ~((hchecksum>>16) + (hchecksum & 0xffff)) & 0xffff; // ~(Header_Checksum[19:16] + Header_Checksum[15:0])

    write_byterev16(&tx_buf[24], (uint16_t)hchecksum);
}

// ARP
// Запись с буфер ARP заголовка
static void MakeEtherHeader(uint64_t dst_mac, uint64_t my_mac, ETHERTYPE ether_type) {
    write_byterev48(&tx_buf[0], dst_mac);
    write_byterev48(&tx_buf[6], my_mac);
    write_byterev16(&tx_buf[12], ether_type);
}

// Посылка ARP пакета
static void SendARP(client ethernet_tx_if i_tx, uint64_t dst_mac, uint64_t my_mac, ARP_OPER arp_oper, uint64_t THA, uint32_t TPA) {
    const uint16_t HTYPE  = 0x0001;   // Ethernet
    const uint16_t PTYPE  = 0x0800;   // IPv4
    const uint8_t HLEN    = 6;        // MAC Address length
    const uint8_t PLEN    = 4;        // Address length IPv4

    MakeEtherHeader(dst_mac, my_mac, ETHERTYPE_ARP);

    write_byterev32(&tx_buf[14], HTYPE<<16 | PTYPE);
    write_byterev32(&tx_buf[18], HLEN<<24 | PLEN<<16 | arp_oper);
    write_byterev32(&tx_buf[22], (uint32_t)(my_mac>>16));
    write_byterev32(&tx_buf[26], (my_mac & 0xffff)<<16 | my_ip>>16);
    write_byterev32(&tx_buf[30], my_ip<<16 | ((uint32_t)(THA>>32) & 0xffff));
    write_byterev32(&tx_buf[34], THA);
    write_byterev32(&tx_buf[38], TPA);
    for (int i = 42; i < 60; i++)
        tx_buf[i] = 0;

    i_tx.send_packet(tx_buf, 60, ETHERNET_ALL_INTERFACES);
}

void SendARPReq(client ethernet_tx_if i_tx, uint64_t my_mac, uint32_t TPA) {
    SendARP(i_tx, MAC_BROADCAST, my_mac, ARP_REQUEST, 0, TPA);
}

void SendARPReq2(client ethernet_tx_if i_tx) {
    SendARP(i_tx, remote_mac, my_mac, ARP_REQUEST, remote_mac, remote_ip);
//    wait_arp = TRUE;
}

void SendARPAnnounce(client ethernet_tx_if i_tx, uint64_t my_mac) {
    SendARPReq(i_tx, my_mac, my_ip);
}

void SendARPReply(client ethernet_tx_if i_tx, uint64_t THA, uint64_t my_mac, uint32_t TPA) {
    SendARP(i_tx, THA, my_mac, ARP_REPLY, THA, TPA);
}

// разбор ARP пакета и формирование ответа
static void arp_parser(unsigned len, client ethernet_tx_if i_tx) {
    uint8_t (& rx_buf)[MTU] = rx_goose.data;

    const uint16_t HTYPE  = 0x0001;   // Ethernet
    const uint16_t PTYPE  = 0x0800;   // IPv4
    const uint8_t HLEN    = 6;        // MAC Address length
    const uint8_t PLEN    = 4;        // Address length IPv4

    uint16_t htype = byterev16(&rx_buf[14 + 0]);
    uint16_t ptype = byterev16(&rx_buf[14 + 2]);
    uint8_t hlen = rx_buf[14 + 4];
    uint8_t plen = rx_buf[14 + 5];
    uint8_t arp_oper = byterev16(&rx_buf[14 + 6]);

    uint32_t tpa = byterev32(&rx_buf[14 + 24]);

    if (htype == HTYPE && ptype == PTYPE && hlen == HLEN && plen == PLEN) {
        switch ((ARP_OPER)arp_oper) {
            case ARP_REQUEST: // Request
                if (tpa == my_ip) {
                    remote_mac =  byterev48(&rx_buf[14 + 8]);
                    remote_ip = byterev32(&rx_buf[14 + 14]);

                    SendARPReply(i_tx, remote_mac, my_mac, remote_ip); // Reply
                    debug_printf("ARP req\n");
                }
                break;
        }
    }
}

void TestUdp(client ethernet_tx_if i_tx, uint32_t data) {
    debug_printf("%x\n", data);
    init_tx_buf(42 + 8);
    add_uint32(data);
    udp_send(i_tx);
}

uint64_t DstMac(const uint8_t eth_pack[MTU])      { return byterev48(&eth_pack[0]); }
uint64_t SrcMac(const uint8_t eth_pack[MTU])      { return byterev48(&eth_pack[6]); }
uint16_t EthType(const uint8_t eth_pack[MTU])     { return byterev16(&eth_pack[12]); } // 0x800
uint8_t IPVer(const uint8_t eth_pack[MTU])        { return eth_pack[14] >> 4 & 0xf; } // 4
uint8_t IPHeaderLen(const uint8_t eth_pack[MTU])  { return eth_pack[14] & 0xf; } // 5
// 15 - 0
uint16_t TotalLen(const uint8_t eth_pack[MTU])    { return byterev16(&eth_pack[16]); }
uint16_t ID(const uint8_t eth_pack[MTU])          { return byterev16(&eth_pack[18]); }
// 20 - offset = 0
// 22 - ttl = 0
uint8_t Protocol(const uint8_t eth_pack[MTU])     { return eth_pack[23]; }
uint16_t HChecksum(const uint8_t eth_pack[MTU])   { return byterev16(&eth_pack[24]); }
uint32_t SrcIP(const uint8_t eth_pack[MTU])       { return byterev32(&eth_pack[26]); }
uint32_t DstIP(const uint8_t eth_pack[MTU])       { return byterev32(&eth_pack[30]); }
uint16_t SrcPort(const uint8_t eth_pack[MTU])     { return byterev16(&eth_pack[34]); }
uint16_t DstPort(const uint8_t eth_pack[MTU])     { return byterev16(&eth_pack[36]); }
uint16_t Length(const uint8_t eth_pack[MTU])      { return byterev16(&eth_pack[38]); }
uint16_t Checksum(const uint8_t eth_pack[MTU])    { return byterev16(&eth_pack[40]); }
