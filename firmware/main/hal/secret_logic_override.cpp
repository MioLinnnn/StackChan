/*
 * SPDX-FileCopyrightText: 2026 M5Stack Technology CO LTD
 *
 * SPDX-License-Identifier: MIT
 *
 * secret_logic override — 用 mbedtls 做 RSA-OAEP/SHA-256 加密
 */

#include "hal/utils/secret_logic/secret_logic.h"
#include <sdkconfig.h>
#include <cstring>
#include <string>
#include <string_view>
#include <cstdio>
#include <ctime>

#include "esp_system.h"
#include "esp_mac.h"
#include "esp_log.h"
#include "mbedtls/pk.h"
#include "mbedtls/rsa.h"
#include "mbedtls/base64.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/entropy.h"
#include "mbedtls/error.h"

static const char* TAG = "SecretLogic";

// ============================================================================
// PEM 格式公钥（注意：字符串必须以 '\n' 结尾，且不能有前置空格！）
// ============================================================================

// ESP-IDF 中直接用 constexpr 字符串即可
static const char BLE_PUB_KEY[] =
    "-----BEGIN PUBLIC KEY-----\n"
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAq39sK0dQPzfrWthyi3Xy\n"
    "GQVOQDpmxfeqArafDe0lGutY8mfluE1kuHdZwuNhIeXip+Hmacyw1md36zR93V2D\n"
    "kSrdDYrm+SI5pg4QCob0vLpqzERTSrKHPJHRuD0PVePx6TZpgEg4orwsuTBPvJzb\n"
    "h18qMOYGCAk0MZY2XveLc/nPDT1lYeGjcdj7cCHuUjvFlPLYMxRjmrAom2jt9ZpK\n"
    "P01qHiGg5N2NAy1FTqEmTN+roN8/mv+BFNySDJhxYoTxStqB3ZTaTdx+Gxa3qX/S\n"
    "Dq8NlXGGbCQNBmU2PU8Q/aNdjB//n1IcRBcigLA7BQWwy6O7w0p+kRXhN3eZpcvO\n"
    "ywIDAQAB\n"
    "-----END PUBLIC KEY-----\n";

static const char SVR_PUB_KEY[] =
    "-----BEGIN PUBLIC KEY-----\n"
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApiXcbaLdBACI3yOGLDuD\n"
    "VBFPHC3NwZm/xVTVPUjwaxFoLxhMAXplehqUJd+Qd+K/g01B8h4pplkhpJZktLBe\n"
    "LC9nW5E97Jjw6sVqqneDuaGbwMyfio/qclsmkLUhY+zJdDEVm2OGowLE8QnggPPb\n"
    "Eq+MKSOnqZWRs/NLwRJsVj432KTehEXlx8BzV43WGfz6bb0SlEct7cCpXXzXcT7P\n"
    "oBAbGcJizzO8zkYxEWhvPnoBVuDubCl4sMkF6wwYWaBuxqT2b0H3vBE3pXGeovdx\n"
    "9hAo2yQQYtqeL+IRomv5bhFkoWKAX2S7g2oo5lbqfbqZnNTucNB9jpRv8Ods0Tq5\n"
    "dQIDAQAB\n"
    "-----END PUBLIC KEY-----\n";

// ============================================================================
// RSA 加密函数（带日志，方便调试）
// ============================================================================

static std::string rsa_encrypt_base64(const char* pub_key_pem,
                                       const std::string& plain)
{
    int ret;
    char err_buf[128];

    // 1. 解析 PEM 公钥
    mbedtls_pk_context pk;
    mbedtls_pk_init(&pk);

    // 调试：打印 PEM 首尾字节
    ESP_LOGI(TAG, "PEM first 80 bytes: %.80s", pub_key_pem);
    ESP_LOGI(TAG, "PEM last 60 bytes: %.60s",
             pub_key_pem + strlen(pub_key_pem) - 60);
    const size_t pem_len = strlen(pub_key_pem) + 1;
    ESP_LOGI(TAG, "PEM total length: %u", static_cast<unsigned>(pem_len));

    ret = mbedtls_pk_parse_public_key(&pk,
        (const unsigned char*)pub_key_pem, pem_len);
    if (ret != 0) {
        mbedtls_strerror(ret, err_buf, sizeof(err_buf));
        ESP_LOGE(TAG, "parse public key failed: -0x%04X (%s)", -ret, err_buf);
        mbedtls_pk_free(&pk);
        return "";
    }
    ESP_LOGI(TAG, "RSA public key parsed OK");

    // 2. 获取 RSA context 并设置 OAEP/SHA-256 padding
    mbedtls_rsa_context* rsa = mbedtls_pk_rsa(pk);
    if (!rsa) {
        ESP_LOGE(TAG, "not an RSA key");
        mbedtls_pk_free(&pk);
        return "";
    }
    mbedtls_rsa_set_padding(rsa, MBEDTLS_RSA_PKCS_V21, MBEDTLS_MD_SHA256);

    size_t key_len = mbedtls_rsa_get_len(rsa);
    ESP_LOGI(TAG, "RSA key length: %d bytes", key_len);

    // 3. 随机数生成器
    mbedtls_ctr_drbg_context ctr_drbg;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_init(&ctr_drbg);
    mbedtls_entropy_init(&entropy);

    ret = mbedtls_ctr_drbg_seed(&ctr_drbg,
                                mbedtls_entropy_func, &entropy, nullptr, 0);
    if (ret != 0) {
        mbedtls_strerror(ret, err_buf, sizeof(err_buf));
        ESP_LOGE(TAG, "ctr_drbg_seed failed: -0x%04X (%s)", -ret, err_buf);
        mbedtls_ctr_drbg_free(&ctr_drbg);
        mbedtls_entropy_free(&entropy);
        mbedtls_pk_free(&pk);
        return "";
    }

    // 4. RSA-OAEP 加密
    // ESP-IDF 的 mbedtls 3.x：rsaes_oaep_encrypt 无 mode 参数
    unsigned char* ciphertext = (unsigned char*)malloc(key_len);
    if (!ciphertext) {
        ESP_LOGE(TAG, "malloc failed");
        mbedtls_ctr_drbg_free(&ctr_drbg);
        mbedtls_entropy_free(&entropy);
        mbedtls_pk_free(&pk);
        return "";
    }

    size_t olen = 0;
    ret = mbedtls_rsa_rsaes_oaep_encrypt(
        rsa, mbedtls_ctr_drbg_random, &ctr_drbg,
        nullptr, 0,  // label = null, label_len = 0
        plain.length(),
        (const unsigned char*)plain.data(),
        ciphertext);
    // RSA-2048 密文固定等于密钥长度
    olen = key_len;

    if (ret != 0) {
        mbedtls_strerror(ret, err_buf, sizeof(err_buf));
        ESP_LOGE(TAG, "RSA OAEP encrypt failed: -0x%04X (%s)", -ret, err_buf);
        free(ciphertext);
        mbedtls_ctr_drbg_free(&ctr_drbg);
        mbedtls_entropy_free(&entropy);
        mbedtls_pk_free(&pk);
        return "";
    }

    ESP_LOGI(TAG, "RSA encrypt OK, ciphertext=%d bytes, plain=\"%s\"",
             olen, plain.c_str());

    // 4. Base64 编码
    size_t b64_len = 0;
    mbedtls_base64_encode(nullptr, 0, &b64_len, ciphertext, olen);

    // 用 new[] 分配，返回 std::string
    std::string result(b64_len, '\0');
    ret = mbedtls_base64_encode((unsigned char*)result.data(), b64_len,
                                &b64_len, ciphertext, olen);
    if (ret != 0) {
        mbedtls_strerror(ret, err_buf, sizeof(err_buf));
        ESP_LOGE(TAG, "Base64 encode failed: -0x%04X (%s)", -ret, err_buf);
        free(ciphertext);
        mbedtls_ctr_drbg_free(&ctr_drbg);
        mbedtls_entropy_free(&entropy);
        mbedtls_pk_free(&pk);
        return "";
    }

    result.resize(b64_len);

    // 去掉末尾可能有的字符串结束符或换行
    while (!result.empty() &&
           (result.back() == '\0' || result.back() == '\n' || result.back() == '\r')) {
        result.pop_back();
    }

    ESP_LOGI(TAG, "Base64 result: %d chars, starts with: %.32s",
             result.length(), result.c_str());

    // 清理
    free(ciphertext);
    mbedtls_ctr_drbg_free(&ctr_drbg);
    mbedtls_entropy_free(&entropy);
    mbedtls_pk_free(&pk);

    return result;
}

// ============================================================================
// 三个公开接口
// ============================================================================

namespace secret_logic {

std::string get_server_url()
{
#ifdef CONFIG_STACKCHAN_SERVER_URL
    return CONFIG_STACKCHAN_SERVER_URL;
#else
    return "http://8.148.197.134:12800";
#endif
}

std::string generate_handshake_token(std::string_view data)
{
    // 读工厂 MAC
    uint8_t mac[6];
    esp_read_mac(mac, ESP_MAC_EFUSE_FACTORY);

    char mac_str[16];
    snprintf(mac_str, sizeof(mac_str), "%02X%02X%02X%02X%02X%02X",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

    std::string encrypted = rsa_encrypt_base64(BLE_PUB_KEY,
                                                std::string(mac_str));

    if (encrypted.empty()) {
        ESP_LOGW(TAG, "BLE handshake RSA failed, fallback to plain MAC");
        return std::string(mac_str);
    }

    ESP_LOGI(TAG, "BLE handshake OK, MAC=%s -> %d bytes cipher",
             mac_str, encrypted.length());
    return encrypted;
}

std::string generate_auth_token()
{
    uint8_t mac[6];
    esp_read_mac(mac, ESP_MAC_EFUSE_FACTORY);

    char mac_str[16];
    snprintf(mac_str, sizeof(mac_str), "%02X%02X%02X%02X%02X%02X",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

    time_t now;
    time(&now);

    char plain[64];
    snprintf(plain, sizeof(plain), "%s|StackChan|%lld", mac_str, (long long)now);

    std::string encrypted = rsa_encrypt_base64(SVR_PUB_KEY,
                                                std::string(plain));

    if (encrypted.empty()) {
        ESP_LOGW(TAG, "Auth token RSA failed, fallback");
        return "hi-stack-chan";
    }

    ESP_LOGI(TAG, "Auth token generated, %d bytes", encrypted.length());
    return encrypted;
}

}  // namespace secret_logic
