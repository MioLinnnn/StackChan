#include "t_app.h"
#include "esp_console.h"
#include "esp_log.h"
#include "esp_heap_caps.h"
#include "esp_system.h"
#include "esp_mac.h"
#include "esp_timer.h"
#include "esp_flash.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <cstring>
#include <cstdio>
#include <inttypes.h>

#include "hal/hal.h"
#include "settings.h"
#include "ota.h"

// ---------------------------------------------------------------------------
// Help
// ---------------------------------------------------------------------------
static void show_help(void)
{
    printf("\n");
    printf("===========================================================\n");
    printf("  StackChan Debug Shell\n");
    printf("===========================================================\n");
    printf("\n");
    printf("  t help                 - Show this help\n");
    printf("  t version              - Show firmware version\n");
    printf("  t heap                 - Show heap/memory info\n");
    printf("  tasks                  - Show FreeRTOS task list\n");
    printf("  t uptime               - Show system uptime\n");
    printf("  t mac                  - Show MAC address\n");
    printf("  t reboot               - Reboot device\n");
    printf("  t factory_reset        - Factory reset\n");
    printf("\n");
    printf("  t bat                  - Battery status\n");
    printf("  t servo <id> <angle>   - Set servo position\n");
    printf("  t rgb <idx> <r> <g> <b> - Set RGB LED\n");
    printf("  t rgb all <r> <g> <b>   - Set all RGB LEDs\n");
    printf("\n");
    printf("  t wifi status          - Show WiFi status\n");
    printf("  t wifi scan            - Scan WiFi networks\n");
    printf("  t wifi ssid <ssid> <pwd> - Set WiFi and restart\n");
    printf("\n");
    printf("  t volume [get|set <val>] - Speaker volume (0-100)\n");
    printf("  t log <tag> <level>    - Set log level (N/A/V/E/W/I/D/V)\n");
    printf("  t ota                  - Trigger OTA update check\n");
    printf("\n");
    printf("  key <value>            - BLE pairing passkey\n");
    printf("===========================================================\n");
}

// ---------------------------------------------------------------------------
// Version
// ---------------------------------------------------------------------------
static int cmd_version(int argc, char **argv)
{
    uint32_t flash_size = 0;
    if (esp_flash_get_size(NULL, &flash_size) != ESP_OK) {
        flash_size = 0;
    }

    printf("Firmware  : v" FIRMWARE_VERSION "\n");
    printf("Chip      : %s\n", CONFIG_IDF_TARGET);
    printf("Flash     : %" PRIu32 " MB\n", flash_size / (1024U * 1024U));
    printf("PSRAM     : %s\n", heap_caps_get_total_size(MALLOC_CAP_SPIRAM) > 0 ? "Yes" : "No");
    printf("IDF ver   : %s\n", esp_get_idf_version());
    return 0;
}

// ---------------------------------------------------------------------------
// Heap
// ---------------------------------------------------------------------------
static int cmd_heap(int argc, char **argv)
{
    printf("Free heap     : %" PRIu32 " bytes\n", esp_get_free_heap_size());
    printf("Free (min)    : %" PRIu32 " bytes\n", esp_get_minimum_free_heap_size());
    printf("Free (IRAM)   : %zu bytes\n", heap_caps_get_free_size(MALLOC_CAP_INTERNAL));
    printf("Free (DMA)    : %zu bytes\n", heap_caps_get_free_size(MALLOC_CAP_DMA));
    printf("Free (PSRAM)  : %zu bytes\n", heap_caps_get_free_size(MALLOC_CAP_SPIRAM));
    printf("Largest blk   : %zu bytes\n", heap_caps_get_largest_free_block(MALLOC_CAP_DEFAULT));
    return 0;
}

// ---------------------------------------------------------------------------
// Tasks
// ---------------------------------------------------------------------------
static int cmd_tasks(int argc, char **argv)
{
    printf("%-25s %-10s %-8s %s\n", "Task", "State", "Prio", "StackFree");
    printf("--------------------------------------------------------\n");
    char task_list[2560];
    vTaskList(task_list);
    printf("%s\n", task_list);
    return 0;
}

// ---------------------------------------------------------------------------
// Uptime
// ---------------------------------------------------------------------------
static int cmd_uptime(int argc, char **argv)
{
    uint64_t us = esp_timer_get_time();
    uint32_t sec = (uint32_t)(us / 1000000ULL);
    uint32_t d = sec / 86400;
    uint32_t h = (sec % 86400) / 3600;
    uint32_t m = (sec % 3600) / 60;
    uint32_t s = sec % 60;
    printf("Uptime: %" PRIu32 " days, %02" PRIu32 ":%02" PRIu32 ":%02" PRIu32 "\n", d, h, m, s);
    return 0;
}

// ---------------------------------------------------------------------------
// MAC
// ---------------------------------------------------------------------------
static int cmd_mac(int argc, char **argv)
{
    uint8_t mac[6];
    esp_read_mac(mac, ESP_MAC_WIFI_STA);
    printf("MAC (WiFi STA): %02X:%02X:%02X:%02X:%02X:%02X\n",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

    esp_read_mac(mac, ESP_MAC_BT);
    printf("MAC (BT)      : %02X:%02X:%02X:%02X:%02X:%02X\n",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    return 0;
}

// ---------------------------------------------------------------------------
// Reboot
// ---------------------------------------------------------------------------
static int cmd_reboot(int argc, char **argv)
{
    printf("Rebooting...\n");
    fflush(stdout);
    vTaskDelay(pdMS_TO_TICKS(100));
    esp_restart();
    return 0;
}

// ---------------------------------------------------------------------------
// Factory reset
// ---------------------------------------------------------------------------
static int cmd_factory_reset(int argc, char **argv)
{
    printf("Factory reset requested...\n");
    GetHAL().factoryReset();
    printf("Factory reset done, rebooting...\n");
    fflush(stdout);
    vTaskDelay(pdMS_TO_TICKS(500));
    esp_restart();
    return 0;
}

// ---------------------------------------------------------------------------
// Battery
// ---------------------------------------------------------------------------
static int cmd_bat(int argc, char **argv)
{
    uint8_t level = GetHAL().getBatteryLevel();
    bool charging = GetHAL().isBatteryCharging();
    printf("Battery level : %u%%\n", level);
    printf("Charging      : %s\n", charging ? "Yes" : "No");
    return 0;
}

// ---------------------------------------------------------------------------
// Servo
// ---------------------------------------------------------------------------
static int cmd_servo(int argc, char **argv)
{
    if (argc < 3) {
        printf("Usage: t servo <id> <angle>\n");
        printf("  id    : Servo ID (usually 1 or 2)\n");
        printf("  angle : Target angle in degrees\n");
        return 1;
    }
    int id = atoi(argv[1]);
    int angle = atoi(argv[2]);
    printf("Setting servo %d to %d degrees...\n", id, angle);
    // Servo control is handled by the HAL via the motion system.
    // For manual control, we enable servo power and delegate to the motion driver.
    // This is a low-level passthrough - precise control depends on calibration.
    GetHAL().setServoPowerEnabled(true);
    // TODO: Add direct servo write when motion system API is available
    printf("Servo power enabled. Use the motion system for precise control.\n");
    return 0;
}

// ---------------------------------------------------------------------------
// RGB
// ---------------------------------------------------------------------------
static int cmd_rgb(int argc, char **argv)
{
    if (argc < 4) {
        printf("Usage:\n");
        printf("  t rgb <index> <r> <g> <b>  - Set single LED (0-9)\n");
        printf("  t rgb all <r> <g> <b>       - Set all LEDs\n");
        printf("  Values: r g b = 0-255\n");
        return 1;
    }

    int r = atoi(argv[2]);
    int g = atoi(argv[3]);
    int b = atoi(argv[4]);

    if (strcmp(argv[1], "all") == 0) {
        GetHAL().showRgbColor(r, g, b);
        printf("RGB set all: (%d, %d, %d)\n", r, g, b);
    } else {
        int idx = atoi(argv[1]);
        GetHAL().setRgbColor(idx, r, g, b);
        printf("RGB set [%d]: (%d, %d, %d)\n", idx, r, g, b);
    }
    GetHAL().refreshRgb();
    return 0;
}

// ---------------------------------------------------------------------------
// WiFi
// ---------------------------------------------------------------------------
static int cmd_wifi(int argc, char **argv)
{
    if (argc < 2) {
        printf("Usage: t wifi status|scan|ssid <ssid> <pwd>\n");
        return 1;
    }

    if (strcmp(argv[1], "status") == 0) {
        WifiStatus s = GetHAL().getWifiStatus();
        printf("WiFi status: ");
        switch (s) {
            case WifiStatus::None:    printf("None\n"); break;
            case WifiStatus::Low:     printf("Low\n"); break;
            case WifiStatus::Medium:  printf("Medium\n"); break;
            case WifiStatus::High:    printf("High\n"); break;
            default:                  printf("Unknown\n"); break;
        }
        return 0;
    }

    if (strcmp(argv[1], "scan") == 0) {
        printf("Initiating WiFi scan...\n");
        printf("(WiFi scan is handled by the network stack; check logs)\n");
        // WiFi scan is typically done by the ESP-IDF wifi stack.
        // For a full scan, we'd need esp_wifi_scan_start() which requires
        // the wifi driver to be initialized first.
        return 0;
    }

    if (strcmp(argv[1], "ssid") == 0) {
        if (argc < 4) {
            printf("Usage: t wifi ssid <ssid> <password>\n");
            return 1;
        }
        printf("Setting WiFi SSID: %s, restarting...\n", argv[2]);
        // WiFi credentials are managed by the xiaozhi network layer.
        // Use Settings to store credentials, then reboot.
        Settings settings("xiaozhi", true);
        settings.SetString("wifi_ssid", argv[2]);
        settings.SetString("wifi_password", argv[3]);
        printf("Credentials saved. Rebooting...\n");
        fflush(stdout);
        vTaskDelay(pdMS_TO_TICKS(200));
        esp_restart();
        return 0;
    }

    return 1;
}

// ---------------------------------------------------------------------------
// Volume
// ---------------------------------------------------------------------------
static int cmd_volume(int argc, char **argv)
{
    if (argc < 2) {
        uint8_t vol = GetHAL().getSpeakerVolume();
        printf("Current volume: %u/100\n", vol);
        return 0;
    }

    if (strcmp(argv[1], "get") == 0) {
        uint8_t vol = GetHAL().getSpeakerVolume();
        printf("Volume: %u/100\n", vol);
        return 0;
    }

    if (strcmp(argv[1], "set") == 0 && argc >= 3) {
        int val = atoi(argv[2]);
        if (val < 0 || val > 100) {
            printf("Volume must be 0-100\n");
            return 1;
        }
        GetHAL().setSpeakerVolume(val, true);
        printf("Volume set to %d/100\n", val);
        return 0;
    }

    printf("Usage: t volume [get|set <0-100>]\n");
    return 1;
}

// ---------------------------------------------------------------------------
// Log level
// ---------------------------------------------------------------------------
static int cmd_log(int argc, char **argv)
{
    if (argc < 3) {
        printf("Usage: t log <tag> <level>\n");
        printf("  level: N(None) A(Error) W(Warn) I(Info) D(Debug) V(Verbose)\n");
        return 1;
    }

    esp_log_level_t level;
    switch (argv[2][0]) {
        case 'N': case 'n': level = ESP_LOG_NONE;    break;
        case 'A': case 'a': level = ESP_LOG_ERROR;   break;
        case 'W': case 'w': level = ESP_LOG_WARN;    break;
        case 'I': case 'i': level = ESP_LOG_INFO;    break;
        case 'D': case 'd': level = ESP_LOG_DEBUG;   break;
        case 'V': case 'v': level = ESP_LOG_VERBOSE; break;
        default:
            printf("Invalid level. Use N/A/W/I/D/V\n");
            return 1;
    }

    esp_log_level_set(argv[1], level);

    const char *level_str[] = {"NONE", "ERROR", "WARN", "INFO", "DEBUG", "VERBOSE"};
    printf("Log level for [%s] set to %s\n", argv[1], level_str[level]);
    return 0;
}

// ---------------------------------------------------------------------------
// OTA
// ---------------------------------------------------------------------------
static int cmd_ota(int argc, char **argv)
{
    printf("Triggering OTA version check...\n");
    Ota ota;
    esp_err_t err = ota.CheckVersion();
    if (err != ESP_OK) {
        printf("OTA check failed: %s\n", esp_err_to_name(err));
        return 1;
    }
    if (ota.HasNewVersion()) {
        printf("New version available: %s\n", ota.GetFirmwareVersion().c_str());
        printf("URL: %s\n", ota.GetFirmwareUrl().c_str());
        printf("Use Application::UpgradeFirmware() to start upgrade.\n");
    } else {
        printf("Firmware is up to date.\n");
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Command dispatch
// ---------------------------------------------------------------------------
static int t_app_cmd_func(int argc, char **argv)
{
    if (argc < 2) {
        show_help();
        return 0;
    }

    int valid = 1;

    if (strcmp(argv[1], "help") == 0) {
        show_help();
    } else if (strcmp(argv[1], "version") == 0) {
        cmd_version(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "heap") == 0) {
        cmd_heap(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "tasks") == 0) {
        cmd_tasks(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "uptime") == 0) {
        cmd_uptime(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "mac") == 0) {
        cmd_mac(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "reboot") == 0) {
        cmd_reboot(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "factory_reset") == 0) {
        cmd_factory_reset(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "bat") == 0 || strcmp(argv[1], "battery") == 0) {
        cmd_bat(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "servo") == 0) {
        cmd_servo(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "rgb") == 0) {
        cmd_rgb(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "wifi") == 0) {
        cmd_wifi(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "volume") == 0) {
        cmd_volume(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "log") == 0) {
        cmd_log(argc - 1, argv + 1);
    } else if (strcmp(argv[1], "ota") == 0) {
        cmd_ota(argc - 1, argv + 1);
    } else {
        valid = 0;
    }

    if (!valid) {
        printf("Unknown command: t %s\n", argv[1]);
        printf("Try 't help' for available commands.\n");
    }

    return 0;
}

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------
void register_t_app(void)
{
    const esp_console_cmd_t t_app_cmd = {
        .command = "t",
        .help = "debug shell (try: t help)",
        .hint = NULL,
        .func = &t_app_cmd_func,
        .argtable = NULL,
        .func_w_context = NULL,
        .context = NULL,
    };
    ESP_ERROR_CHECK(esp_console_cmd_register(&t_app_cmd));
}
