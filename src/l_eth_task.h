/*
 * Локальные функции и переменные задачи eth_task
 */

#ifndef L_ETH_TASK_H_
#define L_ETH_TASK_H_

/* Local types */

// Структура для хранения минимального и максимального периода повторения GOOSE сообщений
typedef struct {
    uint32_t T_min;
    uint32_t T_max;
} Settings;

// кода Ethernet адресов для фильтра сообщений
typedef enum {MY_MAC_INDEX, BROADCAST_MAC_INDEX} MAC_INDEX;

/* Local variables */

extern uint64_t my_mac; // MAC адрес устройства
extern sens_param_t l_param;

extern uint64_t remote_mac; // MAC адрес удаленного устройства
extern uint32_t my_ip; // IP адрес устройства
extern uint32_t remote_ip; // IP адрес удаленного устройства
extern uint16_t my_port; // UDP порт устройства
extern uint16_t remote_port; // UDP порт удаленного устройства
extern BOOL goose_ena; // штаные GOOSE сообщения включены
extern BOOL goose_req; // флаг запроса изменения параметров GOOSE
extern BOOL arp_req; // запрос включения ARP
extern BOOL soft_rst_req; // запрос програмного сброса параметров GOOSE

extern Settings set; // настройки GOOSE
extern OscSettings osc_set; // cтруктура с параметрами работы осцилографа

/* Local functions */

/* Внутренняя функция чтения шаблона параметров работы из Flash памяти
 * print_ena    вкл./откл. печати дополнительной отладочной информации
 */
void GooseInit0(BOOL print_ena);

/* Внутренняя функция установки параметров работы устройства из значений по умолчанию
 * В случае, если чтение Flash памяти оказалось не удачным
 * fabric_ena   использовать фабричные параметры по умолчанию
 * goose_ena    использовать шаблон GOOSE по умолчанию
 * set_ena      использовать настройки GOOSE по умолчанию
 */
void SetDefault(BOOL fabric_ena, BOOL goose_ena, BOOL set_ena);

#endif /* L_ETH_TASK_H_ */
