/*
 * SPDX-FileCopyrightText: 2026 M5Stack Technology CO LTD
 *
 * SPDX-License-Identifier: MIT
 *
 * secret_logic override — 覆盖 weak 默认实现，提供真实的 RSA 加密
 *
 * 密钥对应关系：
 *   generate_handshake_token → 用 rsa_client_public 加密 MAC
 *     → App 用 stackChanBluePrivateKey 解密
 *   generate_auth_token     → 用 rsa_server_public 加密 MAC|padding|timestamp
 *     → 服务器用 rsa.server.private 解密验证
 *   get_server_url          → 返回你的服务器地址
 */

#include "hal/utils/secret_logic/secret_logic.h"
#include <sdkconfig.h>
#include <cstring>
#include <string>
#include <string_view>
#include <mbedtls/rsa.h>
#include <mbedtls/pk.h>
#include <mbedtls/base64.h>
#include <mbedtls/ctr_drbg.h>
#include <mbedtls/entropy.h>
#include "esp_system.h"
#include "esp_log.h"

static const char* TAG = "SecretLogic";

// ============================================================================
// RSA Public Keys (PEM format)
// ============================================================================

// 客户端公钥 — BLE 握手用（加密 MAC 发给 App）
// 对应 App 的 stackChanBluePrivateKey
static const char* BLE_PUBLIC_KEY_PEM = R"(
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAq39sK0dQPzfrWthyi3Xy
GQVOQDpmxfeqArafDe0lGutY8mfluE1kuHdZwuNhIeXip+Hmacyw1md36zR93V2D
kSrdDYrm+SI5pg4QCob0vLpqzERTSrKHPJHRuD0PVePx6TZpgEg4orwsuTBPvJzb
h18qMOYGCAk0MZY2XveLc/nPDT1lYeGjcdj7cCHuUjvFlPLYMxRjmrAom2jt9ZpK
P01qHiGg5N2NAy1FTqEmTN+roN8/mv+BFNySDJhxYoTxStqB3ZTaTdx+Gxa3qX/S
Dq8NlXGGbCQNBmU2PU8Q/aNdjB//n1IcRBcigLA7BQWwy6O7w0p+kRXhN3eZpcvO
ywIDAQAB
-----END PUBLIC KEY-----
)";

// 服务器公钥 — WebSocket 认证用（加密 token 发给服务器）
// 对应服务器 config.yaml 的 rsa.server.private
static const char* SERVER_PUBLIC_KEY_PEM = R"(
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApiXcbaLdBACI3yOGLDuD
VBFPHC3NwZm/xVTVPUjwaxFoLxhMAXplehqUJd+Qd+K/g01B8h4pplkhpJZktLBe
LC9nW5E97Jjw6sVqqneDuaGbwMyfio/qclsmkLUhY+zJdDEVm2OGowLE8QnggPPb
Eq+MKSOnqZWRs/NLwRJsVj432KTehEXlx8BzV43WGfz6bb0SlEct7cCpXXzXcT7P
oBAbGcJizzO8zkYxEWhvPnoBVuDubCl4sMkF6wwYWaBuxqT2b0H3vBE3pXGeovdx
9hAo2yQQYtqeL+IRomv5bhFkoWKAX2S7g2oo5lbqfbqZnNTucNB9jpRv8Ods0Tq5
dQIDAQAB
-----END PUBLIC KEY-----
)";

// ============================================================================
// RSA 工具函数
// ============================================================================

/**
 * 从 PEM 格式加载 RSA 公钥
 */
static mbedtls_rsa_context* load_public_key(const char* pem)
{
    mbedtls_pk_context pk;
    mbedtls_pk_init(&pk);

    int ret = mbedtls_pk_parse_public_key(&pk,
        (const unsigned char*)pem, strlen(pem) + 1);
    if (ret != 0) {
        ESP_LOGE(TAG, "Failed to parse public key: -0x%04X", -ret);
        mbedtls_pk_free(&pk);
        return nullptr;
    }

    mbedtls_rsa_context* rsa = mbedtls_pk_rsa(pk);
    if (!rsa) {
        ESP_LOGE(TAG, "Not an RSA key");
        mbedtls_pk_free(&pk);
        return nullptr;
    }

    return rsa;
}

/**
 * RSA-OAEP/SHA-256 加密 + Base64 编码
 * @param public_key_pem PEM 格式公钥
 * @param plain 明文
 * @return Base64 编码的密文，失败返回空字符串
 */
static std::string rsa_encrypt_base64(const char* public_key_pem,
                                       const std::string& plain)
{
    mbedtls_pk_context pk;
    mbedtls_pk_init(&pk);

    int ret = mbedtls_pk_parse_public_key(&pk,
        (const unsigned char*)public_key_pem, strlen(public_key_pem) + 1);
    if (ret != 0) {
        ESP_LOGE(TAG, "RSA parse key failed: -0x%04X", -ret);
        mbedtls_pk_free(&pk);
        return "";
    }

    mbedtls_rsa_context* rsa = mbedtls_pk_rsa(pk);
    size_t key_len = mbedtls_rsa_get_len(rsa);

    // 随机数生成器
    mbedtls_ctr_drbg_context ctr_drbg;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_init(&ctr_drbg);
    mbedtls_entropy_init(&entropy);
    mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy,
                          nullptr, 0);

    // 加密
    unsigned char ciphertext[key_len];
    size_t olen = 0;

    ret = mbedtls_rsa_rsaes_oaep_encrypt(
        rsa, mbedtls_ctr_drbg_random, &ctr_drbg,
        MBEDTLS_RSA_PUBLIC,
        nullptr, 0,
        (const unsigned char*)plain.data(), plain.length(),
        ciphertext, &olen);

    mbedtls_ctr_drbg_free(&ctr_drbg);
    mbedtls_entropy_free(&entropy);
    mbedtls_pk_free(&pk);

    if (ret != 0) {
        ESP_LOGE(TAG, "RSA encrypt failed: -0x%04X", -ret);
        return "";
    }

    // Base64 编码
    size_t b64_len = 0;
    mbedtls_base64_encode(nullptr, 0, &b64_len, ciphertext, olen);

    std::string result(b64_len, '\0');
    ret = mbedtls_base64_encode((unsigned char*)result.data(), b64_len,
                                &b64_len, ciphertext, olen);
    if (ret != 0) {
        ESP_LOGE(TAG, "Base64 encode failed: -0x%04X", -ret);
        return "";
    }

    // 去掉末尾的换行/null
    while (!result.empty() &&
           (result.back() == '\n' || result.back() == '\0')) {
        result.pop_back();
    }

    return result;
}

// ============================================================================
// 获取服务器地址
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

// ============================================================================
// 生成 BLE 握手 token（加密的 MAC 地址）
// ============================================================================
//
// App 发送 {"cmd":"handshake","data":"<timestamp>"}
// 固件返回 {"cmd":"notifyState","data":{"type":4,"state":"<RSA加密的MAC>"}}
// App 用 stackChanBluePrivateKey 解密得到 MAC
//
std::string generate_handshake_token(std::string_view data)
{
    // 读取工厂 MAC 地址
    uint8_t mac[6];
    esp_read_mac(mac, ESP_MAC_EFUSE_FACTORY);

    char mac_str[13];
    snprintf(mac_str, sizeof(mac_str), "%02X%02X%02X%02X%02X%02X",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

    // 明文格式: "MAC"
    std::string plain(mac_str);

    // 用 BLE 公钥 RSA 加密 + Base64
    std::string encrypted = rsa_encrypt_base64(BLE_PUBLIC_KEY_PEM, plain);

    if (encrypted.empty()) {
        ESP_LOGE(TAG, "BLE handshake encryption failed, fallback to plain MAC");
        return std::string(mac_str);  // 降级返回明文
    }

    ESP_LOGI(TAG, "BLE handshake token generated for MAC: %s", mac_str);
    return encrypted;
}

// ============================================================================
// 生成 WebSocket 认证 token
// ============================================================================
//
// 固件连接 WebSocket 时，在 URL 参数中携带此 token
// 服务器用 rsa.server.private 解密，验证 MAC 和时间戳
//
// 格式: "MAC|padding|timestamp" → RSA 加密 → Base64 编码
//
std::string generate_auth_token()
{
    // 读取 MAC
    uint8_t mac[6];
    esp_read_mac(mac, ESP_MAC_EFUSE_FACTORY);

    char mac_str[13];
    snprintf(mac_str, sizeof(mac_str), "%02X%02X%02X%02X%02X%02X",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

    // 时间戳（Unix 秒）
    time_t now;
    time(&now);

    // 构造明文: MAC|padding|timestamp
    char plain[64];
    snprintf(plain, sizeof(plain), "%s|StackChan|%ld", mac_str, now);

    // 用服务器公钥 RSA 加密 + Base64
    std::string encrypted = rsa_encrypt_base64(SERVER_PUBLIC_KEY_PEM,
                                                std::string(plain));

    if (encrypted.empty()) {
        ESP_LOGE(TAG, "Auth token encryption failed, fallback");
        return "hi-stack-chan";
    }

    ESP_LOGI(TAG, "Auth token generated for MAC: %s", mac_str);
    return encrypted;
}

}  // namespace secret_logic
