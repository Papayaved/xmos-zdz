#ifndef FLASH_H_
#define FLASH_H_
#include "all_libs.h"
#include "my_types.h"
#include "sensor_task.h"

#define FLASH_BUFFER_SIZE (256)
#define FLASH_MAGIC (0xefbeadde) //(0xDEADBEEF)
#define FLASH_CRC (0xedb15ad1) //(0xD15AB1ED)
#define VISIBLE_STRING_LENGTH (35)

extern const uint64_t DEFAULT_MAC;
extern const uint8_t DEFAULT_MODEL[VISIBLE_STRING_LENGTH];
extern const uint8_t DEFAULT_SN[VISIBLE_STRING_LENGTH];

extern uint8_t page[FLASH_BUFFER_SIZE];

extern fl_QSPIPorts flashPorts;
extern fl_QuadDeviceSpec flashSpecs[];
extern const unsigned FLASH_SPECS_LEN;

typedef struct {
    uint8_t mac[MACADDR_NUM_BYTES]; // mac address
    uint8_t model[VISIBLE_STRING_LENGTH]; // OrionZDZ, Null terminated
    uint8_t sn[VISIBLE_STRING_LENGTH]; // decimal serial number in ASCII, Null terminated
} factory_t;

void ReadFactory0(factory_t* const p_fac, sens_param_t* const p_param);
void ReadSettings0(BOOL print_ena);

#endif /* FLASH_H_ */
