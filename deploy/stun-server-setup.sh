#!/bin/bash
# ============================================================================
# LinkChat STUN 服务器部署脚本（Debian 12）
#
# 作用：在云服务器上部署 coturn 的 STUN-only 模式（不开 TURN）
# 用法：
#   1. 上传本文件到云服务器
#   2. chmod +x deploy_stun.sh
#   3. ./deploy_stun.sh
# 退出后服务在后台运行，日志在 /var/log/turnserver.log
# 不设开机自启，重启后需重新执行本脚本
# ============================================================================

set -e

echo "=========================================="
echo "  LinkChat STUN 部署脚本（Debian 12）"
echo "=========================================="

# 1. 安装
echo ""
echo "[1/5] 安装 coturn..."
sudo apt update
sudo apt install -y coturn

# 2. 写配置
echo ""
echo "[2/5] 写入 /etc/turnserver.conf..."
SERVER_IP=$(curl -s ifconfig.me)
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: 无法获取本机公网 IP，请检查网络"
  exit 1
fi
echo "    本机公网 IP: $SERVER_IP"

sudo tee /etc/turnserver.conf > /dev/null <<EOF
# STUN-only 模式配置（不开 TURN 用户名密码）
listening-port=3478
listening-ip=0.0.0.0
external-ip=$SERVER_IP
realm=linkchat.local
log-file=/var/log/turnserver.log
simple-log
verbose
EOF

# 3. 关闭系统自启
echo ""
echo "[3/5] 关闭系统自启（手动管理）..."
sudo systemctl stop coturn 2>/dev/null || true
sudo systemctl disable coturn 2>/dev/null || true
if [ -f /etc/default/coturn ]; then
  sudo sed -i 's/^ENABLE_COTURN=.*/ENABLE_COTURN=false/' /etc/default/coturn
fi

# 4. 放行端口
echo ""
echo "[4/5] 放行 3478 端口..."
if sudo iptables -L -n 2>/dev/null | grep -q "Chain INPUT"; then
  sudo iptables -I INPUT -p udp --dport 3478 -j ACCEPT
  sudo iptables -I INPUT -p tcp --dport 3478 -j ACCEPT
  echo "    iptables 规则已添加"
else
  if ! sudo nft list table inet filter 2>/dev/null | grep -q "chain inet filter input"; then
    sudo nft add table inet filter
    sudo nft 'add chain inet filter input { type filter hook input priority 0 ; policy accept ; }'
  fi
  sudo nft add rule inet filter input udp dport 3478 accept
  sudo nft add rule inet filter input tcp dport 3478 accept
  echo "    nftables 规则已添加"
fi

# 5. 后台启动
echo ""
echo "[5/5] 后台启动 coturn..."

# 先杀掉已有的
sudo pkill -f "turnserver -c /etc/turnserver.conf" 2>/dev/null || true
sleep 1

# 后台启动
nohup sudo /usr/bin/turnserver -c /etc/turnserver.conf > /tmp/turn.log 2>&1 &
sleep 2

# 验证
echo ""
echo "=========================================="
echo "  部署结果"
echo "=========================================="
echo ""
echo "[进程状态]"
if ps aux | grep "turnserver -c /etc/turnserver.conf" | grep -v grep > /dev/null; then
  echo "  ✅ coturn 正在运行"
  ps aux | grep "turnserver -c /etc/turnserver.conf" | grep -v grep | awk '{print "     PID:", $2}'
else
  echo "  ❌ coturn 未运行，请检查 /tmp/turn.log"
  tail -20 /tmp/turn.log
  exit 1
fi

echo ""
echo "[端口监听]"
if sudo ss -uln | grep -q ":3478"; then
  echo "  ✅ UDP 3478 监听中"
else
  echo "  ❌ UDP 3478 未监听"
fi
if sudo ss -tln | grep -q ":3478"; then
  echo "  ✅ TCP 3478 监听中"
else
  echo "  ❌ TCP 3478 未监听"
fi

echo ""
echo "=========================================="
echo "  客户端配置"
echo "=========================================="
echo ""
echo "  在客户端 lib/utils/constants.dart 中加入："
echo ""
echo "    {'urls': 'stun:$SERVER_IP:3478'},"
echo ""
echo "  ⚠️  重要：去云服务商控制台的安全组放行 3478 TCP/UDP"
echo ""
echo "  其他命令："
echo "    查看日志:    tail -f /var/log/turnserver.log"
echo "    停止服务:    sudo pkill -f turnserver"
echo "    重启服务:    nohup sudo /usr/bin/turnserver -c /etc/turnserver.conf > /tmp/turn.log 2>&1 &"
echo ""
