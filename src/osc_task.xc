#include "all_libs.h"
#include "osc_task.h"
#include "defines.h"

// ������ ������������
//[[combinable]]
[[distributable]]
void OscTask(
        server osc_if i_osc[n], unsigned n,
        server osc_eth_if i_osc_eth)
{
    debug_printf("OscTask\n");

    static int32_t buf[ADC_NUM][BUF_SIZE]; // 3 ������ FIFO

    BOOL enable[ADC_NUM] = {FALSE, FALSE, FALSE}; // ����������� �������
    BOOL trigger[ADC_NUM] = {FALSE, FALSE, FALSE}; // ������ �� ������� ���������� ������������
    unsigned wraddr[ADC_NUM] = {0, 0, 0}; // ����� ������
    unsigned pos_cnt[ADC_NUM] = {0, 0, 0}; // ������� ��������
    BOOL isTriggered = FALSE; // ������������� ������������
    unsigned start_pos = 0; // �������� �������� ������ �������

#ifdef PRINT_OSC
    // ��������� ����������� ������ ������
    start_pos = 16;
    enable[0] = TRUE;
    trigger[0] = TRUE;
#endif

    while (1) {
        select {
            case i_osc[unsigned x].Add(int adc): // ���������� ������ ������ �� ���
                if (enable[x]) {
                    buf[x][wraddr[x]++] = adc; // ������ ������ � FIFO
                    wraddr[x] &= BUF_MASK;

                    // ������ ���������� ������ ����� ������������
                    if (isTriggered && pos_cnt[x] >= BUF_SIZE - start_pos) {
#ifdef PRINT_OSC
                        for (int i = (wraddr[x] + 1) & BUF_MASK, k = 0; i != wraddr[x]; i = ( i + 1) & BUF_MASK, k++) {
                            if ((k & 7) == 0) debug_printf("\n");
                            debug_printf("%d", buf[i]);
                            if ((k & 7) != 7) debug_printf(" ");
                        }
#else
                        enable[x] = FALSE; // ��������� ������ �� ������ x

                        debug_printf("pos_cnt[%x] = %d\n", x, pos_cnt[x]);

                        if (!enable[0] && !enable[1] && !enable[2])
                            i_osc_eth.osc_ready(); // ����������� � ���������� ������
                    }
                    else
                        pos_cnt[x]++;
                }
#endif
                break;

            case i_osc[unsigned x].Trigger(): // ���������� ������� ������������
                if (enable[x] && trigger[x] && !isTriggered) {
                    isTriggered = TRUE;
                    for (int i = 0; i < ADC_NUM; i++)
                        pos_cnt[i] = 0;

                    debug_printf("Osc trig %x\n", x);
                }

                break;

            // ���������� �������� Ethernet ������ ������� ������������
            case i_osc_eth.get_data(unsigned osc_num, unsigned it, uint8_t data[n], unsigned n):
                unsigned startPos = (wraddr[osc_num] + 1) & BUF_MASK;

                unsigned size = (BUF_SIZE - startPos) * sizeof(int32_t);
                size = MIN(size, n - it);

                if (size != 0 && it < n) {
                    memcpy(&data[it], (uint8_t*)&buf[osc_num][startPos], size);
                    it += size;
                }

                size = startPos * sizeof(int32_t);
                size = MIN(size, n - it);

                if (size != 0 && it < n)
                    memcpy(&data[it], (uint8_t*)buf[osc_num], size);

                debug_printf("Get osc %x\n", osc_num);

                break;

            // ������ ��������� ������ ������
            case i_osc_eth.run(const OscSettings& set):
                unsigned ff = set.trig_ff;

                if (ff) {
                    isTriggered = FALSE;
                    start_pos = set.startPos;

                    for (int i = 0; i < ADC_NUM; i++, ff >>= 1) {
                        enable[i] = TRUE;
                        trigger[i] = ff & 1;
                        wraddr[i] = 0;
                    }

                    debug_printf("Osc ena %x%x%x ch %x%x%x pos %d\n",
                            enable[0], enable[1], enable[2],
                            trigger[0], trigger[1], trigger[2],
                            start_pos);
                }
                else {
                    start_pos = 0;

                    for (int i = 0; i < ADC_NUM; i++) {
                        enable[i] = FALSE;
                        trigger[i] = FALSE;
                        wraddr[i] = 0;
                    }

                    debug_printf("Osc OFF\n");
                }

                break;
        }
    }
}
