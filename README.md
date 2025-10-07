# Alpine Xray 一键安装脚本

这是一个为 **Alpine Linux** 系统设计的 Xray 一键安装脚本，用于快速部署最新版本的 Xray 代理服务。脚本支持交互式配置，生成标准 VMess 链接，并自动配置开机启动，适合快速搭建代理服务器。

仓库地址: [https://github.com/xinguddos/alpine-xray](https://github.com/xinguddos/alpine-xray)
## 功能特性

- **自动安装最新 Xray**：从 GitHub 获取并安装最新版本的 Xray。
- **交互式配置**：
  - 端口：默认 42003，可自定义。
  - WebSocket 路径：必须输入，无默认值。
  - Host 域名：必须输入，无默认值。
  - 自动生成随机 UUID 作为客户端 ID。
- **生成 VMess 链接**：安装完成后输出标准 VMess URL，方便导入客户端。
- **开机自启**：使用 OpenRC 配置 Xray 服务，确保系统重启后自动运行。
- **Alpine Linux 优化**：专为 Alpine Linux 设计，依赖最小化。

## 依赖要求

- **操作系统**：Alpine Linux
- **权限**：需要 root 权限运行脚本
- **网络**：服务器需能访问 GitHub（下载 Xray）和外部网络
- **软件包**：脚本会自动安装以下依赖：
  - `curl`
  - `unzip`
  - `jq`
  - `openrc`
 
## 安装方法
克隆仓库或下载脚本：
   ```bash
   git clone https://github.com/xinguddos/alpine-xray.git
   cd alpine-xray
   ```

或者直接下载：
   ```bash
   curl -O https://raw.githubusercontent.com/xinguddos/alpine-xray-/refs/heads/main/install_xray.sh
   ```
添加执行权限：
   ```
   chmod +x install_xray.sh
   ```
以 root 权限运行脚本：
   ```
   sudo ./install_xray.sh
   ```
按提示输入配置参数：
   - **端口**：建议使用默认值 `42003`，或输入其他未被占用的端口。
   - **WebSocket 路径**：输入有效路径（如 `/ws`），不能为空。
   - **Host 域名**：输入服务器的域名或 IP，需确保能解析到服务器，不能为空。
---

### 使用说明

- **配置输出**：脚本完成后会显示：
  - 使用的端口、WebSocket 路径、Host 域名和客户端 ID。
  - VMess 链接（格式：`vmess://...`），可直接导入支持 VMess 的客户端（如 v2rayNG、V2Ray 桌面客户端）。
- **验证服务**：检查 Xray 服务状态：
  ```bash
  rc-service xray status
  ```
  - 应显示 started。如果显示 crashed，参考故障排除。
---

### 故障排除

1. **服务状态为 crashed**：
   - 检查配置文件：
     ```bash
     jq . /usr/local/etc/xray/config.json
     ```
     如果报错，编辑 `/usr/local/etc/xray/config.json` 修复 JSON 格式。
   - 查看日志：
     ```bash
     cat /var/log/xray/error.log
     ```
     启用日志（编辑配置文件，设置 `"loglevel": "debug"`)。
   - 确保端口未被占用：
     ```bash
     netstat -tuln | grep <端口号>
     ```

2. **VMess 链接无法连接**：
   - 确保 `HOST_DOMAIN` 解析到服务器 IP：
     ```bash
     ping <HOST_DOMAIN>
     ```
   - 检查防火墙是否开放端口：
     ```bash
     iptables -L -n
     ```

3. **其他问题**：
   - 重新运行脚本，输入有效参数。
   - 查看详细日志：`/var/log/xray/error.log`。
   - 提交 issue 到 [GitHub Issues](https://github.com/xinguddos/alpine-xray/issues)。

## 注意事项

- **域名解析**：确保 `HOST_DOMAIN` 已正确解析到服务器 IP。
- **端口冲突**：避免使用已被占用的端口。
- **WebSocket 路径**：建议使用简单路径（如 `/ws`），避免特殊字符。
- **防火墙**：确保配置的端口（默认 42003）在防火墙中开放。
- **日志启用**：如需调试，修改 `/usr/local/etc/xray/config.json`，启用日志：
  ```json
  "log": {
    "loglevel": "debug",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  }
  ```
  Nat使用CDN处 主机名等于域名转发到端口
