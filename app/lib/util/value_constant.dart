/*
 * SPDX-FileCopyrightText: 2026 M5Stack Technology CO LTD
 *
 * SPDX-License-Identifier: MIT
 */

/// Application-wide constant values and configuration
///
/// This class contains:
/// - API response keys for JSON parsing
/// - Language support configuration
/// - RSA encryption keys for secure communication
/// - Character sets for random generation
/// - Bluetooth encryption keys
///
/// Backend Configuration Notes:
/// - Update serverPublicKey and clientPrivateKey for your backend server
/// - These keys are used for RSA-OAEP encryption with SHA-256
/// - For production, use environment variables instead of hardcoding
class ValueConstant {
  // ===========================================================================
  // API Response Keys - Used for JSON parsing from backend responses
  // ===========================================================================

  /// Authentication token key for HTTP headers and storage
  static const String token = "token";

  /// Device-specific token key for device authentication
  static const String deviceToken = "deviceToken";

  /// Authorization header key for Bearer token authentication
  static const String authorization = "Authorization";

  /// Device type identifier key
  static const String deviceType = "deviceType";

  /// MAC address key for device identification
  static const String mac = "mac";

  /// Index key for pagination or list positioning
  static const String index = "index";

  /// Data payload key in API responses
  static const String data = "data";

  /// List key for array responses
  static const String list = "list";

  /// File upload/download identifier key
  static const String file = "file";

  /// Directory path key for file operations
  static const String directory = "directory";

  /// Moments or timeline content key
  static const String moments = "moments";

  /// Name field key for various entities
  static const String name = "name";

  /// Dance choreography data key
  static const String danceData = "danceData";

  /// Dance name/title key
  static const String danceName = "danceName";

  /// Music file URL key
  static const String musicUrl = "musicUrl";

  /// Text content key for messages or posts
  static const String contentText = "content_text";

  /// Image content key for media attachments
  static const String contentImage = "content_image";

  /// Page number key for pagination
  static const String page = "page";

  /// Page size key for pagination results
  static const String pageSize = "pageSize";

  /// Generic ID key for various entities
  static const String id = "id";

  /// Post identifier key for social content
  static const String postId = "postId";

  /// Content body key
  static const String content = "content";

  /// Comment identifier key
  static const String commentId = "commentId";

  /// Random seed key for deterministic operations
  static const String seed = "seed";

  /// Device control mode configuration key
  static const String deviceControlMode = "deviceControlMode";

  /// Login status flag key
  static const String isLogin = "isLogin";

  /// Username field key for authentication
  static const String username = "username";

  /// Password field key for authentication
  static const String password = "password";

  /// Email address field key
  static const String email = "email";

  /// Application version identifier key
  static const String appVersion = "app_version";

  // ===========================================================================
  // Bluetooth BLE Advertisement Data Keys
  // ===========================================================================

  /// Manufacturer specific data key in BLE advertisement
  static const String manufacturerData = "manufacturerData";

  /// Service data key in BLE advertisement
  static const String serviceData = "serviceData";

  /// Service UUID list key in BLE advertisement
  static const String serviceUuids = "serviceUuids";

  /// Connectable flag key in BLE advertisement
  static const String connectable = "connectable";

  /// Transmit power level key in BLE advertisement
  static const String txPowerLevel = "txPowerLevel";

  /// Advertised device name key
  static const String advName = "advName";

  /// Device serial number key for identification
  static const String serialNumber = "serialNumber";

  /// Device MAC address key (alternative)
  static const String deviceMac = "deviceMac";

  /// Device unique identifier key
  static const String deviceId = "deviceId";

  // ===========================================================================
  // Language Support Configuration
  // ===========================================================================

  /// Supported languages map
  /// Key: Language code (ISO 639-1)
  /// Value: Display name in English and native language
  static const Map<String, String> languages = {
    "en": "English",
    "zh": "Chinese Mandarin 普通话",
    "yue": "Cantonese 粵語",
    "ja": "Japanese 日本語",
    "ko": "Korean 한국어",
    "ru": "Russian Русский",
    "es": "Spanish Español",
    "ar": "Arabic العربية",
    "fr": "French Français",
    "vi": "Vietnamese Tiếng Việt",
    "it": "Italian Italiano",
    "id": "Indonesian Bahasa Indonesia",
    "hi": "Hindi हिन्दी",
    "fi": "Finnish Suomi",
    "th": "Thai ไทย",
    "de": "German Deutsch",
    "pt": "Portuguese Português",
    "uk": "Ukrainian Українська",
    "tr": "Turkish Türkçe",
    "cs": "Czech Čeština",
    "pl": "Polish Polski",
    "ro": "Romanian Română",
    "ca": "Catalan Català",
    "nl": "Dutch Nederlands",
    "sv": "Swedish Svenska",
    "da": "Danish Dansk",
    "no": "Norwegian Norsk",
    "et": "Estonian Eesti",
    "lv": "Latvian Latviešu",
    "lt": "Lithuanian Lietuvių",
    "is": "Icelandic Íslenska",
    "ms": "Malay Bahasa Melayu",
    "sl": "Slovenian Slovenščina",
    "bg": "Bulgarian Български",
    "he": "Hebrew עברית",
    "sk": "Slovak Slovenčina",
    "hr": "Croatian Hrvatski",
    "hu": "Hungarian Magyar",
    "fa": "Persian فارسی",
    "el": "Greek Ελληνικά",
    "fil": "Filipino Filipino",
  };

  // ===========================================================================
  // RSA Encryption Keys - Backend Configuration
  // ===========================================================================

  /// Server RSA Public Key for encrypting outgoing requests
  ///
  /// IMPORTANT BACKEND CONFIGURATION:
  /// - This key must match the public key from your backend server
  /// - Used for RSA-OAEP encryption with SHA-256 padding
  /// - Encrypt sensitive data before sending to server
  ///
  /// To replace with your backend key:
  /// 1. Generate RSA key pair on your server (2048-bit recommended)
  /// 2. Extract the public key in PEM format
  /// 3. Replace the content below with your server's public key
  static const String serverPublicKey = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApiXcbaLdBACI3yOGLDuD
VBFPHC3NwZm/xVTVPUjwaxFoLxhMAXplehqUJd+Qd+K/g01B8h4pplkhpJZktLBe
LC9nW5E97Jjw6sVqqneDuaGbwMyfio/qclsmkLUhY+zJdDEVm2OGowLE8QnggPPb
Eq+MKSOnqZWRs/NLwRJsVj432KTehEXlx8BzV43WGfz6bb0SlEct7cCpXXzXcT7P
oBAbGcJizzO8zkYxEWhvPnoBVuDubCl4sMkF6wwYWaBuxqT2b0H3vBE3pXGeovdx
9hAo2yQQYtqeL+IRomv5bhFkoWKAX2S7g2oo5lbqfbqZnNTucNB9jpRv8Ods0Tq5
dQIDAQAB
-----END PUBLIC KEY-----''';

  /// Client RSA Private Key for decrypting incoming responses
  ///
  /// IMPORTANT SECURITY NOTE:
  /// - In production, DO NOT hardcode this key!
  /// - Use secure storage, environment variables, or key management service
  /// - This private key should ONLY be used for development/testing
  ///
  /// Key Usage:
  /// - Decrypt data encrypted with the corresponding public key
  /// - Used for secure server-to-client communication
  static const String clientPrivateKey = '''-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAq39sK0dQPzfrWthyi3XyGQVOQDpmxfeqArafDe0lGutY8mfl
uE1kuHdZwuNhIeXip+Hmacyw1md36zR93V2DkSrdDYrm+SI5pg4QCob0vLpqzERT
SrKHPJHRuD0PVePx6TZpgEg4orwsuTBPvJzbh18qMOYGCAk0MZY2XveLc/nPDT1l
YeGjcdj7cCHuUjvFlPLYMxRjmrAom2jt9ZpKP01qHiGg5N2NAy1FTqEmTN+roN8/
mv+BFNySDJhxYoTxStqB3ZTaTdx+Gxa3qX/SDq8NlXGGbCQNBmU2PU8Q/aNdjB//
n1IcRBcigLA7BQWwy6O7w0p+kRXhN3eZpcvOywIDAQABAoIBAArtg6b+VE6y8XxI
boQUb+jIPcQ59HKI5XxmxpvMkKC2fmRz2l90DwbyE/YnJvlR/K9V5ai4Mkx3K10B
a0O/wbJuWMeUIkOduq6qFruU/eNIvaVmdSg9WAC0CfkDawa+D5wcq3xRHcrA0ti6
C1qpZBOsLLQQ9DFu5LSELdK/U1OAbMK86lbxY2sJg6A6z1QAnvB5TVszxbD8tQXl
dY4xsUHVWAPqSp86M4VKQVRs+B5EoKuvZ8c5Bv92luQ3NXN+8RfLdVVctw/qUcVB
TC7F+EKIO9rHpPM/PHx4IRPyl+5klKYsSsWHAoBEQxhM9weyrzd/r983wlbtIUv7
u1gz14ECgYEAxkj7zN2fNEY9G2QuAGbedbaILls5LujeURwyrjux0f1z7kN0TSVQ
U+ncWtmmeiAgbCwuRJdBDnBVKiT5lj97IZloPQohClO5PAcWa6UQVMmmVbvUU6Zc
5v+9Im6VZwgyVzPFCJ6cZuweAsDEV21uH+a/A/jj6P96uVwwXvVnzr8CgYEA3Wpo
Bx2Ia3dSZNgQZqLJBj0NncwEWLGsM4lbzL5eNFzoktOrdINsr8/jou+wVyIoQ1wq
ZIoR7bVZ5cVoUSmiip8FkkMklVVFe/lUj7DukVie4tKInf9kGYnOewlZyz838wzF
0Z6ELI93clno/M7nkjtGWbJkhu/MrLFIveF7jvUCgYEAwie8x4FK3rjYJPYXRTV1
JvYwqpOQjqpe5jUiOxEgsWnoFqneO5wJ5+Dab+sm4/aJSOKJ+4fPn//GpJnH+qL2
QpQgSYSdjaslee3GumjKcPty8AgXhEEmPtqzq/90M4sHH/QFPsdwhic1y6RNnP3+
Eyaya4VORVvEI7RteM37c6kCgYBNYlgTTI4WSTDB0AYDaRdrF8F/igNm4En4BSTR
bSNNl78tOc9tvFUrKTQ9CRqPiX+a80ZZtyvG8aAGvzTTUQLfAe8XjGHn01KinqSg
R81JfTiiu8RFvDHG/zPsKnt4npK2XptwxL8bN9UeYTAd0055/D99L+0UgBD/tkJf
IsRlVQKBgHdLPBsW9CZJoSSs93yZRVwNJ4YHp1ePEyF7LM2ANWhriRh4iYtR5wAW
xgfngNgdd3wsPw95n1V/In5ZgQ0PX0z/XcjjB3K/1Tu+pALe9Gov470qUIqwreyJ
+/4LV9yUORmvmfUQPD0N1nLeckzbeui5Pe9vB2miXQi6uR6P0XVu
-----END RSA PRIVATE KEY-----''';

  // ===========================================================================
  // Character Sets
  // ===========================================================================

  /// Alphanumeric character set for random string generation
  /// Contains: uppercase, lowercase letters, and digits 0-9
  static const List<String> characters = [
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];

  // ===========================================================================
  // Bluetooth Encryption Key
  // ===========================================================================

  /// StackChan Bluetooth RSA Private Key
  ///
  /// This key is used for secure communication with StackChan hardware devices
  /// over Bluetooth Low Energy (BLE). It enables encrypted communication
  /// between the mobile app and the StackChan robot.
  ///
  /// Note: Each StackChan device should have a unique key pair in production.
  /// This is a default development key for testing purposes.
  static const stackChanBluePrivateKey = '''-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAq39sK0dQPzfrWthyi3XyGQVOQDpmxfeqArafDe0lGutY8mfl
uE1kuHdZwuNhIeXip+Hmacyw1md36zR93V2DkSrdDYrm+SI5pg4QCob0vLpqzERT
SrKHPJHRuD0PVePx6TZpgEg4orwsuTBPvJzbh18qMOYGCAk0MZY2XveLc/nPDT1l
YeGjcdj7cCHuUjvFlPLYMxRjmrAom2jt9ZpKP01qHiGg5N2NAy1FTqEmTN+roN8/
mv+BFNySDJhxYoTxStqB3ZTaTdx+Gxa3qX/SDq8NlXGGbCQNBmU2PU8Q/aNdjB//
n1IcRBcigLA7BQWwy6O7w0p+kRXhN3eZpcvOywIDAQABAoIBAArtg6b+VE6y8XxI
boQUb+jIPcQ59HKI5XxmxpvMkKC2fmRz2l90DwbyE/YnJvlR/K9V5ai4Mkx3K10B
a0O/wbJuWMeUIkOduq6qFruU/eNIvaVmdSg9WAC0CfkDawa+D5wcq3xRHcrA0ti6
C1qpZBOsLLQQ9DFu5LSELdK/U1OAbMK86lbxY2sJg6A6z1QAnvB5TVszxbD8tQXl
dY4xsUHVWAPqSp86M4VKQVRs+B5EoKuvZ8c5Bv92luQ3NXN+8RfLdVVctw/qUcVB
TC7F+EKIO9rHpPM/PHx4IRPyl+5klKYsSsWHAoBEQxhM9weyrzd/r983wlbtIUv7
u1gz14ECgYEAxkj7zN2fNEY9G2QuAGbedbaILls5LujeURwyrjux0f1z7kN0TSVQ
U+ncWtmmeiAgbCwuRJdBDnBVKiT5lj97IZloPQohClO5PAcWa6UQVMmmVbvUU6Zc
5v+9Im6VZwgyVzPFCJ6cZuweAsDEV21uH+a/A/jj6P96uVwwXvVnzr8CgYEA3Wpo
Bx2Ia3dSZNgQZqLJBj0NncwEWLGsM4lbzL5eNFzoktOrdINsr8/jou+wVyIoQ1wq
ZIoR7bVZ5cVoUSmiip8FkkMklVVFe/lUj7DukVie4tKInf9kGYnOewlZyz838wzF
0Z6ELI93clno/M7nkjtGWbJkhu/MrLFIveF7jvUCgYEAwie8x4FK3rjYJPYXRTV1
JvYwqpOQjqpe5jUiOxEgsWnoFqneO5wJ5+Dab+sm4/aJSOKJ+4fPn//GpJnH+qL2
QpQgSYSdjaslee3GumjKcPty8AgXhEEmPtqzq/90M4sHH/QFPsdwhic1y6RNnP3+
Eyaya4VORVvEI7RteM37c6kCgYBNYlgTTI4WSTDB0AYDaRdrF8F/igNm4En4BSTR
bSNNl78tOc9tvFUrKTQ9CRqPiX+a80ZZtyvG8aAGvzTTUQLfAe8XjGHn01KinqSg
R81JfTiiu8RFvDHG/zPsKnt4npK2XptwxL8bN9UeYTAd0055/D99L+0UgBD/tkJf
IsRlVQKBgHdLPBsW9CZJoSSs93yZRVwNJ4YHp1ePEyF7LM2ANWhriRh4iYtR5wAW
xgfngNgdd3wsPw95n1V/In5ZgQ0PX0z/XcjjB3K/1Tu+pALe9Gov470qUIqwreyJ
+/4LV9yUORmvmfUQPD0N1nLeckzbeui5Pe9vB2miXQi6uR6P0XVu
-----END RSA PRIVATE KEY-----''';
}