#include <platform.h>
#include "flash.h"
#include "aux_func.h"
#include "goose.h"
#include "defines.h"
#include "eth_task.h"
#include "l_eth_task.h"

//const uint64_t DEFAULT_MAC = 0x001bc5044071ULL;
const uint64_t DEFAULT_MAC = 0xF8B568E00400ULL;
const uint8_t DEFAULT_MODEL[VISIBLE_STRING_LENGTH] = "OrionZDZ";
const uint8_t DEFAULT_SN[VISIBLE_STRING_LENGTH] = "00000000";

uint8_t page[FLASH_BUFFER_SIZE]; // буфер под страницу flash памяти

fl_QSPIPorts flashPorts = {
    T0_PORT_SQI_CS,
    T0_PORT_SQI_SCLK,
    T0_PORT_SQI_SIO,
    on tile[0] : XS1_CLKBLK_3
};

fl_QuadDeviceSpec flashSpecs[] = {
//    FL_QUADDEVICE_SPANSION_S25FL116K,
//    FL_QUADDEVICE_SPANSION_S25FL132K,
//    FL_QUADDEVICE_SPANSION_S25FL164K,
//    FL_QUADDEVICE_ISSI_IS25LQ080B,
    FL_QUADDEVICE_ISSI_IS25LQ016B,
//    FL_QUADDEVICE_ISSI_IS25LQ032B,
};

const unsigned FLASH_SPECS_LEN = sizeof(flashSpecs) / sizeof(fl_QuadDeviceSpec);

void PrintFlashInfo();
static void _read_flash(BOOL print_ena, BOOL& goose_OK, BOOL& set_OK);

void SetSettingsDefault(BOOL goose_ena, BOOL set_ena);

void ReadSettings0(BOOL print_ena) {
    BOOL goose_OK, set_OK;

    _read_flash(print_ena, goose_OK, set_OK);

    SetSettingsDefault(!goose_OK, !set_OK);

    ParseGoose(main_goose, main_goose.length, TRUE);
    BOOL parse_OK = CheckGooseTemplate(main_goose);

    if (goose_OK && !parse_OK) {
        debug_printf("Parse GOOSE ERROR\n");
        SetSettingsDefault(TRUE, FALSE);
        ParseGoose(main_goose, main_goose.length, TRUE);
    }
    else
        debug_printf("Parse GOOSE OK\n");
}

static BOOL read_flash_data(unsigned offset, uint8_t* read_data, unsigned size, uint16_t& len);

// flash must be mounted
static void _read_flash(BOOL print_ena, BOOL& goose_OK, BOOL& set_OK) {
    goose_OK = FALSE;
    set_OK = FALSE;

    BOOL bMount = FALSE;
    int i = 0;

    while (!bMount) {
        bMount = fl_connectToDevice(flashPorts, flashSpecs, sizeof(flashSpecs) / sizeof(fl_QuadDeviceSpec)) == 0;
        if (!bMount) {
            delay_milliseconds(1);
            if (i++ > 100) break;
        }
    }

    if (bMount) {
    //    unsigned page_num = fl_getNumDataPages();
        unsigned page_size = fl_getPageSize();
    //    unsigned sect_num = fl_getNumDataSectors();
        unsigned sect_size = fl_getDataSectorSize(1);
    //    unsigned flash_size = fl_getFlashSize();

    //    unsigned data_size = page_num * page_size;
    //    unsigned boot_size = flash_size - data_size;

    //    debug_printf("page_size: %d page_num: %d sect_size: %d sect_num: %d\n",\
    //            page_size, page_num, sect_size, sect_num);
    //    debug_printf("flash_size %d (0x%x) data_size: %d (0x%x) boot_size: %d (0x%x)\n",\
    //            flash_size, flash_size, data_size, data_size, boot_size, boot_size);
        if (print_ena) PrintFlashInfo();

        if (page_size <= FLASH_BUFFER_SIZE) {
            debug_printf("Read goose packet...\n");
            goose_OK = read_flash_data(sect_size, main_goose.data, MTU, main_goose.length);
//            PrintByteArray(main_goose.data, main_goose.length);

            debug_printf("Read settings...\n");
            uint16_t set_len;
            set_OK = read_flash_data(sect_size<<1, (uint8_t*)&set, sizeof(Settings), set_len);

            if (set_OK) {
                set_OK = set_OK && set.T_min != 0 && set.T_min != ~0U;
                set_OK = set_OK && set.T_max != 0 && set.T_max != ~0U;
                set_OK = set_OK && set.T_min <= set.T_max;
                if (!set_OK) debug_printf("Settings ERROR\n");
            }
        }
        else
            debug_printf("ERROR! Flash buffer is too small\n");

        fl_disconnect();
    }
    else
        debug_printf("ERROR: Flash mount\n");
}

static BOOL read_flash_data(unsigned offset, uint8_t* read_data, unsigned size, uint16_t& len) {
    uint8_t bytes[2];
    BOOL OK = fl_readData(offset, 2, bytes) == 0;

    if (OK) {
        len = (uint16_t)bytes[1]<<8 | bytes[0];

        OK = len != 0 && len <= size;
        if (OK) {
            debug_printf("size: %d len: %d\n", size, len);
            OK = OK && fl_readData(offset + 2, len, read_data) == 0;

            OK = OK && fl_readData(offset + 2 + len, 2, bytes) == 0;
            uint16_t read_crc = (uint16_t)bytes[1]<<8 | bytes[0];
            debug_printf("Read CRC: %x\n", read_crc);

            uint16_t calc_crc = ModRTU_CRC(read_data, len);
            debug_printf("Calc CRC: %x\n", calc_crc);

            OK = OK && read_crc == calc_crc;
            if (OK) debug_printf("CRC OK\n");
        }
        else
            debug_printf("ERROR! Data len: %d\n", len);
    }

    if (!OK) {
        debug_printf("ERROR! Read flash error\n");
//        PrintByteArray(read_data, size);
    }

    return OK;
}

void PrintFlashInfo() {
    unsigned page_size = fl_getPageSize();
    unsigned page_num = fl_getNumDataPages();
    unsigned sect_size = fl_getDataSectorSize(1);
    unsigned sect_num = fl_getNumDataSectors();
    unsigned flash_size = fl_getFlashSize();
    unsigned data_size = fl_getDataPartitionSize();
    unsigned boot_size = flash_size - data_size;

    fl_BootImageInfo bootImageInfo;

    debug_printf("Soft version: 0x%x\n", SOFT_VER);
    debug_printf("Page size: %d\n", page_size);
    debug_printf("Number data pages: %d\n", page_num);
    debug_printf("Data sector size: %d (0x%x)\n", sect_size, sect_size);
    debug_printf("Number data sectors: %d\n", sect_num);
    debug_printf("Flash size: %d (0x%x)\n", flash_size, flash_size);
    debug_printf("Data size: %d (0x%x)\n", data_size, data_size);
    debug_printf("Boot size: %d (0x%x)\n", boot_size, boot_size);

    // Image info
    if (fl_getFactoryImage(bootImageInfo) == 0) {
        debug_printf("   Factory image:\n");
        debug_printf("bFactory: %x\n", bootImageInfo.factory);
        debug_printf("Image size: %d (0x%x)\n", bootImageInfo.size, bootImageInfo.size);
        debug_printf("Start address: 0x%x\n", bootImageInfo.startAddress);
        debug_printf("Version: %d\n", bootImageInfo.version);

        int i = 0;
        while (fl_getNextBootImage(bootImageInfo) == 0) {
            debug_printf("   Update image %d:\n", i);
            debug_printf("bFactory: %x\n", bootImageInfo.factory);
            debug_printf("Image size: %d (0x%x)\n", bootImageInfo.size, bootImageInfo.size);
            debug_printf("Start address: 0x%x\n", bootImageInfo.startAddress);
            debug_printf("Version: %d\n", bootImageInfo.version);
        }
    }
}

void SetSettingsDefault(BOOL goose_ena, BOOL set_ena) {
    if (goose_ena) {
        main_goose.length = DEFAULT_GOOSE_LEN;
        memcpy(main_goose.data, DEFAULT_GOOSE, DEFAULT_GOOSE_LEN);
    }

    if (set_ena) {
        set.T_min = DEFAULT_T_MIN;
        set.T_max = DEFAULT_T_MAX;
    }

    // todo: write to flash
    //        debug_printf("Default goose packet:\n");
    //        PrintByteArray(defaultGoosePacket, DEFAULT_GOOSE_LEN);
    //        uint16_t crc = ModRTU_CRC(defaultGoosePacket, DEFAULT_GOOSE_LEN);
    //        debug_printf("CRC: %x\n", crc);
    //
    //        int i = 0;
    //        flash.buffer[i++] = (uint8_t)DEFAULT_GOOSE_LEN;
    //        flash.buffer[i++] = (uint8_t)(DEFAULT_GOOSE_LEN >> 8);
    //
    //        for (int j = 0; i < FLASH_BUFFER_SIZE && j < DEFAULT_GOOSE_LEN; i++, j++)
    //            flash.buffer[i] = defaultGoosePacket[j];
    //
    //        flash.buffer[i++] = (uint8_t)crc;
    //        flash.buffer[i++] = (uint8_t)(crc >> 8);
    //
    //        for (; i < FLASH_BUFFER_SIZE; i++)
    //            flash.buffer[i] = 0xFF;
    //
    //        debug_printf("Erase sector 1\n");
    //        OK = fl_eraseDataSector(1) == 0;
    //
    //        debug_printf("Write goose packet\n");
    //        unsigned goose_page_num = sect_size/page_size;
    //        fl_writeDataPage(goose_page_num, flash.buffer);
}

void SetFactoryDefault(factory_t* const p_fac, sens_param_t* const p_param) {
    memcpy(p_fac->mac, (const uint8_t*)&DEFAULT_MAC, MACADDR_NUM_BYTES);
    memcpy(p_fac->model, DEFAULT_MODEL, VISIBLE_STRING_LENGTH);
    memcpy(p_fac->sn, DEFAULT_SN, VISIBLE_STRING_LENGTH);

    p_param->up = UP;
    p_param->dur = DUR;
    p_param->sat = SAT;
    p_param->sat_len = SATLEN;
}

void ReadFactory0(factory_t* const p_fac, sens_param_t* const p_param) {
    BOOL factory_OK = FALSE;
    BOOL bMount = FALSE;
    int i = 0;

    debug_printf("ReadFactory0\n");

    while (!bMount) {
        bMount = fl_connectToDevice(flashPorts, flashSpecs, sizeof(flashSpecs) / sizeof(fl_QuadDeviceSpec)) == 0;
        if (!bMount) {
            delay_milliseconds(1);
            if (i++ > 100) break;
        }
    }

    if (bMount) {
        unsigned page_size = fl_getPageSize();

        if (page_size <= FLASH_BUFFER_SIZE) {
            uint16_t len;
            factory_OK = read_flash_data(0, page, sizeof(factory_t) + sizeof(sens_param_t), len);

            if (factory_OK && len >= sizeof(factory_t) + sizeof(sens_param_t)) {
                memcpy((uint8_t*)p_fac, page, sizeof(factory_t));
                memcpy((uint8_t*)p_param, page + sizeof(factory_t), sizeof(sens_param_t));
            }
            else {
                factory_OK = TRUE;
                SetFactoryDefault(p_fac, p_param);

                debug_printf("Write factory default\n");
                fl_eraseDataSector(0);
                memset(page, 0xFF, FLASH_BUFFER_SIZE);

                page[0] = sizeof(factory_t) + sizeof(sens_param_t);
                page[1] = 0;

                memcpy(&page[2], p_fac, sizeof(factory_t));
                memcpy(&page[2 + sizeof(factory_t)], p_param, sizeof(sens_param_t));

                uint16_t crc = ModRTU_CRC(&page[2], sizeof(factory_t) + sizeof(sens_param_t));
                memcpy(&page[2 + sizeof(factory_t) + sizeof(sens_param_t)], (const uint8_t*)&crc, sizeof(uint16_t));

                fl_writeDataPage(0, page);
            }
        }
        else
            debug_printf("ERROR! Flash buffer is too small\n");

        fl_disconnect();
    }
    else
        debug_printf("Flash mount ERROR!\n");

    if (!factory_OK)
        SetFactoryDefault(p_fac, p_param);
}
