#include "shell.h"
#include "t_app.h"
#include "esp_console.h"
#include "esp_vfs_dev.h"
#include "esp_log.h"

static const char *TAG = "debug_shell";

int shell_init(void)
{
    esp_console_repl_t *repl = NULL;
    esp_console_repl_config_t repl_config = ESP_CONSOLE_REPL_CONFIG_DEFAULT();
    repl_config.prompt = "StackChan>";

    // REPL must use the same port as idf.py monitor input (see sdkconfig console choice).
#if CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG
    esp_console_dev_usb_serial_jtag_config_t usbjtag_config = ESP_CONSOLE_DEV_USB_SERIAL_JTAG_CONFIG_DEFAULT();
    ESP_LOGI(TAG, "Initializing console REPL on USB Serial JTAG");
    ESP_ERROR_CHECK(esp_console_new_repl_usb_serial_jtag(&usbjtag_config, &repl_config, &repl));
#elif CONFIG_ESP_CONSOLE_USB_CDC
    esp_console_dev_usb_cdc_config_t cdc_config = ESP_CONSOLE_DEV_CDC_CONFIG_DEFAULT();
    ESP_LOGI(TAG, "Initializing console REPL on USB CDC");
    ESP_ERROR_CHECK(esp_console_new_repl_usb_cdc(&cdc_config, &repl_config, &repl));
#elif CONFIG_ESP_CONSOLE_UART
    esp_console_dev_uart_config_t uart_config = ESP_CONSOLE_DEV_UART_CONFIG_DEFAULT();
    ESP_LOGI(TAG, "Initializing console REPL on UART");
    ESP_ERROR_CHECK(esp_console_new_repl_uart(&uart_config, &repl_config, &repl));
#else
    ESP_LOGW(TAG, "No console backend configured, skipping REPL init");
    return -1;
#endif

    // Register debug commands
    register_t_app();

    ESP_ERROR_CHECK(esp_console_start_repl(repl));
    ESP_LOGI(TAG, "Debug shell started. Type 't help' for commands.");

    return 0;
}
