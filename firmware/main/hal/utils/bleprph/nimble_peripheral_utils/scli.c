/*
 * SPDX-FileCopyrightText: 2021-2025 Espressif Systems (Shanghai) CO LTD
 *
 * SPDX-License-Identifier: Unlicense OR CC0-1.0
 *
 * Modified for StackChan: stripped UART/console init (now handled by debug_shell REPL).
 * Only retains the command registration and queue for BLE pairing passkey input.
 */

#include <stdio.h>
#include <ctype.h>
#include "esp_log.h"
#include <string.h>
#include <esp_log.h>
#include <esp_console.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/queue.h>
#include "esp_peripheral.h"

#define BLE_RX_TIMEOUT (30000 / portTICK_PERIOD_MS)

static QueueHandle_t cli_handle;

static int enter_passkey_handler(int argc, char *argv[])
{
    int key;
    char pkey[8];
    int num;

    if (argc != 2) {
        return -1;
    }

    sscanf(argv[1], "%7s", pkey);
    ESP_LOGI("You entered", "%s %s", argv[0], argv[1]);
    num = pkey[0];

    if (isalpha(num)) {
        if ((strcasecmp(pkey, "Y") == 0) || (strcasecmp(pkey, "Yes") == 0)) {
            key = 1;
            xQueueSend(cli_handle, &key, 0);
        } else {
            key = 0;
            xQueueSend(cli_handle, &key, 0);
        }
    } else {
        if (sscanf(pkey, "%d", &key) != 1) {
            key = 0;
        }
        xQueueSend(cli_handle, &key, 0);
    }

    return 0;
}

int scli_receive_key(int *console_key)
{
    if (cli_handle == NULL) {
        return pdFALSE;
    }
    return xQueueReceive(cli_handle, console_key, BLE_RX_TIMEOUT);
}

static esp_console_cmd_t cmds[] = {
    {
        .command = "key",
        .help    = "enter BLE pairing passkey",
        .func    = enter_passkey_handler,
    },
};

static int ble_register_cli(void)
{
    int cmds_num = sizeof(cmds) / sizeof(esp_console_cmd_t);
    int i;
    for (i = 0; i < cmds_num; i++) {
        esp_console_cmd_register(&cmds[i]);
    }
    return 0;
}

int scli_init(void)
{
    /* Register CLI "key <value>" — esp_console may not be initialized yet,
     * but esp_console_cmd_register() queues commands internally. */
    ble_register_cli();

    cli_handle = xQueueCreate(1, sizeof(int));
    if (cli_handle == NULL) {
        return ESP_FAIL;
    }
    return ESP_OK;
}

int scli_deinit(void)
{
    if (cli_handle != NULL) {
        vQueueDelete(cli_handle);
        cli_handle = NULL;
    }
    return ESP_OK;
}
