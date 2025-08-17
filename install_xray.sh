#!/bin/sh

# Xray 一键安装脚本 for Alpine Linux
# 默认安装最新版本的 Xray，并配置为开机启动
# Host 域名和 WebSocket 路径无默认值，必须输入非空值
# 安装完成后生成 VMess 配置链接

# 检查是否为 root 用户
if [ "$(id -u)" != "0" ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# 确保系统是 Alpine Linux
if ! grep -qi "alpine" /etc/os-release; then
    echo "Error: This script is designed for Alpine Linux"
    exit 1
fi

# 安装必要的工具
echo "Installing required packages..."
apk update
apk add --no-cache curl unzip jq openrc

# 获取最新版本的 Xray
echo "Fetching the latest Xray version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r .tag_name)
if [ -z "$LATEST_VERSION" ]; then
    echo "Error: Failed to fetch the latest Xray version"
    exit 1
fi
echo "Latest Xray version: $LATEST_VERSION"

# 下载并安装 Xray
DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_VERSION}/Xray-linux-64.zip"
echo "Downloading Xray from $DOWNLOAD_URL..."
curl -L -o xray.zip "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download Xray"
    exit 1
fi

unzip -o xray.zip -d /usr/local/bin/
rm xray.zip
chmod +x /usr/local/bin/xray

# 创建 Xray 配置文件目录
mkdir -p /usr/local/etc/xray
CONFIG_FILE="/usr/local/etc/xray/config.json"

# 交互式输入配置参数
echo "Configuring Xray..."

# 输入监听端口，默认 42003
read -p "Enter the inbound port for VMess [default: 42003]: " INBOUND_PORT
INBOUND_PORT=${INBOUND_PORT:-42003}

# 输入 WebSocket 路径，必须输入
while true; do
    read -p "Enter the WebSocket path (required, cannot be empty): " WS_PATH
    if [ -n "$WS_PATH" ]; then
        break
    else
        echo "Error: WebSocket path cannot be empty"
    fi
done

# 输入 Host 域名，必须输入
while true; do
    read -p "Enter the Host domain (required, cannot be empty): " HOST_DOMAIN
    if [ -n "$HOST_DOMAIN" ]; then
        break
    else
        echo "Error: Host domain cannot be empty"
    fi
done

# 生成随机 UUID 作为客户端 ID
CLIENT_ID=$(cat /proc/sys/kernel/random/uuid)
echo "Generated client ID: $CLIENT_ID"

# 创建配置文件
cat << EOF > $CONFIG_FILE
{
  "log": null,
  "routing": {
    "rules": [
      {
        "inboundTag": ["api"],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "ip": ["geoip:private"],
        "outboundTag": "blocked",
        "type": "field"
      },
      {
        "outboundTag": "blocked",
        "protocol": ["bittorrent"],
        "type": "field"
      }
    ]
  },
  "dns": null,
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 62789,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
    {
      "port": $INBOUND_PORT,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$CLIENT_ID",
            "alterId": 0
          }
        ],
        "disableInsecureEncryption": false
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "$WS_PATH",
          "headers": {
            "Host": "$HOST_DOMAIN"
          }
        }
      },
      "tag": "inbound-$INBOUND_PORT",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "policy": {
    "system": {
      "statsInboundDownlink": true,
      "statsInboundUplink": true
    }
  },
  "api": {
    "services": ["HandlerService", "LoggerService", "StatsService"],
    "tag": "api"
  },
  "stats": {}
}
EOF

# 设置文件权限
chmod 644 $CONFIG_FILE

# 创建 Xray 服务
echo "Creating Xray service for OpenRC..."
cat << EOF > /etc/init.d/xray
#!/sbin/openrc-run

name="xray"
command="/usr/local/bin/xray"
command_args="-config /usr/local/etc/xray/config.json"
pidfile="/run/xray.pid"
command_background="yes"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath -d -m 0755 -o root:root /run
}
EOF

chmod +x /etc/init.d/xray

# 启用开机启动
rc-update add xray default

# 启动 Xray 服务
echo "Starting Xray service..."
rc-service xray start

# 检查服务状态
if rc-service xray status | grep -q "started"; then
    echo "Xray is running successfully."
else
    echo "Error: Xray failed to start. Please check the configuration."
    exit 1
fi

# 生成 VMess 配置链接
# VMess 链接格式: vmess://<base64_encoded_json>
VMESS_JSON=$(cat << EOF
{
  "v": "2",
  "ps": "xray-vmess",
  "add": "$HOST_DOMAIN",
  "port": "$INBOUND_PORT",
  "id": "$CLIENT_ID",
  "aid": 0,
  "net": "ws",
  "type": "none",
  "host": "$HOST_DOMAIN",
  "path": "$WS_PATH",
  "tls": "none"
}
EOF
)

# 对 JSON 进行 base64 编码
VMESS_BASE64=$(echo "$VMESS_JSON" | jq -c . | base64 -w 0)
VMESS_LINK="vmess://$VMESS_BASE64"

echo "Xray installation and configuration completed!"
echo "Xray is configured with the following settings:"
echo "Port: $INBOUND_PORT"
echo "WebSocket Path: $WS_PATH"
echo "Host: $HOST_DOMAIN"
echo "Client ID: $CLIENT_ID"
echo "Configuration file: $CONFIG_FILE"
echo "VMess Link: $VMESS_LINK"
