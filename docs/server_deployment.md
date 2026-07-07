# StackChan 服务器部署指南

> 本文档指导你将 `server/`（Go 后端）部署到一台 Linux 服务器上。

---

## 目录

1. [架构概览](#1-架构概览)
2. [准备工作](#2-准备工作)
3. [部署 MySQL 数据库](#3-部署-mysql-数据库)
4. [生成 RSA 密钥](#4-生成-rsa-密钥)
5. [配置 server/config.yaml](#5-配置-serverconfigyaml)
6. [编译与部署](#6-编译与部署)
7. [验证服务是否正常](#7-验证服务是否正常)
8. [可选：Docker 部署](#8-可选docker-部署)
9. [可选：Kubernetes 部署](#9-可选kubernetes-部署)
10. [故障排查](#10-故障排查)

---

## 1. 架构概览

```
                    ┌──────────────────────┐
                    │    MySQL 数据库       │
                    │    (stackChan)        │
                    └─────────┬────────────┘
                              │ TCP 3306
                              ▼
 ┌────────┐  REST API   ┌──────────────┐  WebSocket  ┌──────────┐
 │  App   │◄───────────►│  Go 后端      │◄────────────│  固件    │
 │(手机端) │  :12800     │  (server/)   │  ws://...   │(机器人)  │
 └────────┘             └──────┬───────┘             └──────────┘
                              │
                              ▼
                    ┌──────────────────────┐
                    │  小智 AI 平台         │
                    │  (xiaozhi.me)        │
                    └──────────────────────┘
```

**端口说明**：
- `:12800` — HTTP REST API + WebSocket
- `:3306` — MySQL 连接

---

## 2. 准备工作

### 2.1 服务器要求

| 项目 | 最低配置 | 推荐配置 |
|------|---------|---------|
| CPU | 1 核 | 2 核 |
| 内存 | 1 GB | 2~4 GB |
| 硬盘 | 10 GB | 20 GB |
| 带宽 | 1 Mbps | 5 Mbps |
| 系统 | Ubuntu 20.04+ / Debian 11+ / CentOS 8+ | 同左 |

### 2.2 安装依赖

```bash
# Go 1.26.3（必须精确版本）
wget https://go.dev/dl/go1.26.3.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.26.3.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
go version  # 验证

# MySQL 8.0+
apt install mysql-server -y   # Ubuntu/Debian
# 或
yum install mysql-server -y   # CentOS

# Git
apt install git -y

# GoFrame CLI（用于编译）
go install github.com/gogf/gf/v2/cmd/gf@latest
```

### 2.3 克隆项目

```bash
git clone https://github.com/m5stack/StackChan.git
cd StackChan/server
```

---

## 3. 部署 MySQL 数据库

### 3.1 启动 MySQL

```bash
# 启动服务
systemctl start mysql
systemctl enable mysql

# 安全配置（设置 root 密码等）
mysql_secure_installation
```

### 3.2 创建数据库和表

```bash
# 登录 MySQL
mysql -u root -p

# 执行建库脚本（请先修改文件中的 root 密码）
source check_list/create_mysql_database.sql
```

建库脚本内容会自动创建：

| 表名 | 用途 |
|------|------|
| `user` | 用户账户 |
| `device` | 硬件设备 |
| `device_dance` | 舞蹈数据 |
| `device_friend` | 设备好友关系 |
| `device_pano` | 全景图 |
| `device_post` | 社交动态 |
| `device_post_comment` | 动态评论 |
| `app_store` | 应用商店 |

### 3.3 创建数据库用户

```sql
-- 在 MySQL 中执行
CREATE USER 'stackchan'@'%' IDENTIFIED BY 'your_strong_password';
GRANT ALL PRIVILEGES ON stackChan.* TO 'stackchan'@'%';
FLUSH PRIVILEGES;
```

记下这个用户名和密码，下一步要用。

---

## 4. 生成 RSA 密钥

服务器需要 4 个 RSA 密钥（2 对）：

| 密钥对 | 用途 |
|--------|------|
| `rsa.server` | 服务器端私钥/公钥（解密 App 发来的请求） |
| `rsa.client` | 客户端私钥/公钥（加密发给 App 的响应） |

在服务器上执行：

```bash
# 安装 Go（如果还没装），然后运行生成脚本
cd StackChan/server

# 用 go run 临时执行一个生成密钥的程序
cat << 'GOEOF' | go run -
package main

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
)

func main() {
	// 生成 server 密钥对
	svrKey, _ := rsa.GenerateKey(rand.Reader, 2048)
	svrPub := &svrKey.PublicKey

	// 生成 client 密钥对
	cliKey, _ := rsa.GenerateKey(rand.Reader, 2048)
	cliPub := &cliKey.PublicKey

	printPEM("rsa.server.private", x509.MarshalPKCS1PrivateKey(svrKey), "RSA PRIVATE KEY")
	printPEM("rsa.server.public", marshalPublicKey(svrPub), "PUBLIC KEY")
	fmt.Println()
	printPEM("rsa.client.private", x509.MarshalPKCS1PrivateKey(cliKey), "RSA PRIVATE KEY")
	printPEM("rsa.client.public", marshalPublicKey(cliPub), "PUBLIC KEY")
}

func marshalPublicKey(pub *rsa.PublicKey) []byte {
	b, _ := x509.MarshalPKIXPublicKey(pub)
	return b
}

func printPEM(name string, der []byte, blockType string) {
	fmt.Printf("# %s\n", name)
	pem.Encode(customWriter{}, &pem.Block{Type: blockType, Bytes: der})
}

type customWriter struct{}
func (customWriter) Write(p []byte) (int, error) { return fmt.Printf("%s", string(p)), nil }
}
GOEOF
```

> 如果 Go 版本不对，也可以用 Python 在本地生成后上传：

```bash
# 在本地安装好 cryptography 的情况下
python3 -c "
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import rsa
import base64, time

# BLE 密钥对
ble = rsa.generate_private_key(65537, 2048)
# Server 密钥对
svr = rsa.generate_private_key(65537, 2048)
svr_pub = svr.public_key()
# Client 密钥对
cli = rsa.generate_private_key(65537, 2048)
cli_pub = cli.public_key()

def pem(k, is_priv):
    if is_priv:
        return k.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL, serialization.NoEncryption()).decode()
    return k.public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo).decode()

print('=== rsa.server.private ===')
print(pem(svr, True))
print('=== rsa.server.public ===')
print(pem(svr_pub, False))
print('=== rsa.client.private ===')
print(pem(cli, True))
print('=== rsa.client.public ===')
print(pem(cli_pub, False))
"
```

---

## 5. 配置 server/config.yaml

复制配置模板并编辑：

```bash
cp manifest/config/config.yaml config.yaml
vim config.yaml
```

填写以下关键字段：

```yaml
server:
  address: ":12800"                    # 监听端口，默认 12800

database:
  default:
    link: "mysql:stackchan:your_strong_password@tcp(127.0.0.1:3306)/stackChan"
    # 格式: mysql:用户名:密码@tcp(主机:端口)/数据库名

jwt:
  secret: "your-random-jwt-secret-key-here-change-it"   # JWT 签名密钥，随机生成

admin:
  users:
    - username: "admin"               # 管理员用户名
      password: "admin_strong_password" # 管理员密码

rsa:
  server:
    public: |
      -----BEGIN PUBLIC KEY-----
      ... 粘贴上一步生成的 rsa.server.public ...
      -----END PUBLIC KEY-----
    private: |
      -----BEGIN RSA PRIVATE KEY-----
      ... 粘贴上一步生成的 rsa.server.private ...
      -----END RSA PRIVATE KEY-----
  client:
    public: |
      -----BEGIN PUBLIC KEY-----
      ... 粘贴上一步生成的 rsa.client.public ...
      -----END PUBLIC KEY-----
    private: |
      -----BEGIN RSA PRIVATE KEY-----
      ... 粘贴上一步生成的 rsa.client.private ...
      -----END RSA PRIVATE KEY-----

xiaozhi:
  secret_key: ""                       # 小智 AI 平台密钥（暂可不填）
  generate_license_token: ""           # 小智授权 token（暂可不填）
```

> **关于小智配置**：如果不打算使用小智 AI 平台的设备管理功能，`xiaozhi.secret_key` 和 `generate_license_token` 可以留空。AI 对话功能由固件直连 `xiaozhi.me`，不经过你的服务器。

---

## 6. 编译与部署

### 6.1 编译二进制文件

```bash
# 在 server/ 目录下执行
cd StackChan/server

# 方法一：用 GoFrame CLI 编译（推荐）
gf build -ew

# 方法二：直接用 go build
go build -o stackChan main.go
```

编译成功后会在当前目录生成 `stackChan` 二进制文件（Linux amd64）。

### 6.2 直接运行

```bash
# 开发测试
./stackChan

# 后台运行
nohup ./stackChan > /var/log/stackchan.log 2>&1 &

# 查看日志
tail -f /var/log/stackchan.log
```

> 默认监听 `:12800`，访问 `http://你的IP:12800/swagger` 可以看到 API 文档。

### 6.3 注册为系统服务（推荐）

```bash
# 创建服务文件
cat > /etc/systemd/system/stackchan.service << 'EOF'
[Unit]
Description=StackChan Server
After=network.target mysql.service

[Service]
Type=simple
WorkingDirectory=/opt/stackchan
ExecStart=/opt/stackchan/stackChan
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 部署文件
mkdir -p /opt/stackchan
cp stackChan /opt/stackchan/
cp config.yaml /opt/stackchan/
mkdir -p /opt/stackchan/logs   # 日志目录

# 启动服务
systemctl daemon-reload
systemctl start stackchan
systemctl enable stackchan

# 查看状态
systemctl status stackchan

# 查看日志
journalctl -u stackchan -f
```

---

## 7. 验证服务是否正常

### 7.1 检查进程

```bash
curl http://localhost:12800/swagger
# 应返回 Swagger/OpenAPI 页面
```

### 7.2 检查 API

```bash
# 查看 API 文档
curl http://localhost:12800/api.json

# 健康检查（如果有的话）
curl http://localhost:12800/stackChan/v2/user
```

### 7.3 检查 WebSocket

```bash
# 测试 WebSocket 连接（用 wscat 工具）
npm install -g wscat
wscat -c "ws://localhost:12800/stackChan/ws?deviceType=App&mac=TEST12345678"
```

### 7.4 检查日志

```bash
tail -f logs/$(date +%Y-%m-%d).log
# 应能看到服务启动、请求处理等日志
```

---

## 8. 可选：Docker 部署

### 8.1 构建镜像

```bash
cd StackChan/server

# 1. 先编译二进制
gf build -ew
# 或
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o stackChan main.go

# 2. 准备配置文件
cp manifest/config/config.yaml config.yaml
# 编辑 config.yaml 填入配置...

# 3. 构建 Docker 镜像
docker build -f manifest/docker/Dockerfile -t stackchan-server:latest .

# 4. 运行容器
docker run -d \
  --name stackchan-server \
  -p 12800:12800 \
  -v $(pwd)/config.yaml:/app/config.yaml \
  -v $(pwd)/logs:/app/logs \
  stackchan-server:latest
```

### 8.2 使用 docker-compose（推荐）

```yaml
# docker-compose.yml
version: '3.8'
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: stackChan
      MYSQL_USER: stackchan
      MYSQL_PASSWORD: your_strong_password
    volumes:
      - mysql_data:/var/lib/mysql
      - ./check_list/create_mysql_database.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "3306:3306"

  server:
    build:
      context: .
      dockerfile: manifest/docker/Dockerfile
    ports:
      - "12800:12800"
    volumes:
      - ./config.yaml:/app/config.yaml
      - ./logs:/app/logs
    depends_on:
      - mysql

volumes:
  mysql_data:
```

```bash
# 启动
docker-compose up -d

# 查看日志
docker-compose logs -f server
```

---

## 9. 可选：Kubernetes 部署

> ⚠️ 注意：Kustomize 清单中有几处 apiVersion 写错了，部署前需要修正

```bash
cd StackChan/server/manifest/deploy/kustomize

# 修正 base 中的 apiVersion
sed -i 's|apiVersion: apps/v2|apiVersion: apps/v1|g' base/deployment.yaml
sed -i 's|apiVersion: v2|apiVersion: v1|g' base/service.yaml
sed -i 's|apiVersion: v2|apiVersion: v1|g' overlays/develop/configmap.yaml
sed -i 's|apiVersion: apps/v2|apiVersion: apps/v1|g' overlays/develop/deployment.yaml

# 预览
kustomize build overlays/develop

# 部署
kustomize build overlays/develop | kubectl apply -f -
```

---

## 10. 故障排查

### 10.1 启动报错

| 问题 | 原因 | 解决 |
|------|------|------|
| `database link is empty` | MySQL 连接未配置 | 检查 `config.yaml` 中 `database.default.link` |
| `RSA keys not initialized` | 密钥为空 | 检查 `config.yaml` 中 `rsa.*` 配置 |
| `jwt secret is empty` | JWT 密钥为空 | 设置 `jwt.secret` |
| `Access denied for user` | MySQL 密码错误 | 验证 MySQL 用户名密码 |
| `port already in use` | 端口被占用 | `netstat -tlnp \| grep 12800` 找冲突进程 |

### 10.2 编译问题

```bash
# Go 版本不对
go version  # 需要 1.26.3

# 依赖下载慢
go env -w GOPROXY=https://goproxy.cn,direct  # 国内加速

# gf 命令找不到
go install github.com/gogf/gf/v2/cmd/gf@latest
export PATH=$PATH:$(go env GOPATH)/bin
```

### 10.3 防火墙问题

```bash
# 开放端口
ufw allow 12800/tcp    # Ubuntu
firewall-cmd --add-port=12800/tcp --permanent  # CentOS
```

---

## 附录：所需文件清单

部署完成后，服务器上应有以下文件结构：

```
/opt/stackchan/
├── stackChan              # 编译好的二进制
├── config.yaml            # 配置文件（含密钥）
├── logs/                  # 日志目录（自动创建）
│   └── 2026-07-07.log
├── file/                  # 文件存储目录
│   └── music/
│       └── stackchan_music.mp3
└── resource/              # 静态资源
    └── public/
```

> 下一步：服务端部署完成后，回到固件 `secret_logic_override.cpp` 中设置 `get_server_url()` 指向你的服务器地址，再编译烧录固件。
