#ifndef MDIO_H_
#define MDIO_H_
#include <smi.h>
#include "my_types.h"

/* Функция проверки подключения Ethernet кабеля
 * i_smi    интерфейс с микросхемой физического уровня Ethernet
 *
 * Возвращаемое значение:
 * TRUE     кабель подсоединен
 * FALSE    нет кабеля
 */
BOOL isPhyLink(client smi_if i_smi);

/* Функция проверка наличия микросхемы физического уровня Ethernet
 * i_smi    интерфейс с микросхемой физического уровня
 *
 * Возвращаемое значение:
 * TRUE     микросхема найдена
 * FALSE    нет микросхемы
 */
BOOL TestMDIO(client smi_if i_smi);

#endif /* MDIO_H_ */
