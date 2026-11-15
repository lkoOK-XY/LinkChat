#!/bin/bash
# ============================================================================
# LinkChat 服务控制脚本（Debian 12）
#
# 作用：管理 coturn STUN 和 Go 信令服务
# 用法：
#   ./linkchat-services.sh start      # 启动所有服务
#   ./linkchat-services.sh stop       # 停止所有服务
#   ./linkchat-services.sh restart    # 重启所有服务
#   ./linkchat-services.sh status     # 查看所有服务状态
#   ./linkchat-services.sh logs stun  # 查看 STUN 日志（实时）
#   ./linkchat-services.sh logs sig   # 查看信令日志（实时）
# ============================================================================

# 配置项（根据你的实际路径调整）
TURN_CONF="/etc/turnserver.conf"
TURN_BIN="/usr/bin/turnserver"
SIGNALING_DIR="$HOME/linkchat-server"  # Go 信令服务器所在目录
# 自动检测信令服务器可执行文件（不挑名字）
# 优先：linkchat-server，其次：linkchat-server-linux
if [ -x "$SIGNALING_DIR/linkchat-server" ]; then
  SIGNALING_BIN="$SIGNALING_DIR/linkchat-server"
  SIGNALING_NAME="linkchat-server"
elif [ -x "$SIGNALING_DIR/linkchat-server-linux" ]; then
  SIGNALING_BIN="$SIGNALING_DIR/linkchat-server-linux"
  SIGNALING_NAME="linkchat-server-linux"
else
  # 兜底：找目录下任何可执行文件（排除 stun-server-setup.sh 等脚本）
  SIGNALING_BIN=$(find "$SIGNALING_DIR" -maxdepth 1 -type f -executable ! -name "*.sh" 2>/dev/null | head -1)
  SIGNALING_NAME=$(basename "$SIGNALING_BIN")
fi

# 信令服务进程匹配模式（用可执行文件名，匹配绝对/相对路径）
SIGNALING_PATTERN="$SIGNALING_NAME"

# ===== 颜色输出 =====
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ===== 检查 =====
check_turn_conf() {
  [ ! -f "$TURN_CONF" ] && { echo -e "${RED}❌ STUN 配置不存在: $TURN_CONF${NC}"; return 1; }
  return 0
}

check_signaling_bin() {
  [ ! -f "$SIGNALING_BIN" ] && { echo -e "${RED}❌ 信令服务器不存在: $SIGNALING_BIN${NC}"; return 1; }
  return 0
}

# ===== STUN 服务 =====
start_stun() {
  if ! check_turn_conf; then return 1; fi
  if pgrep -f "turnserver -c $TURN_CONF" > /dev/null; then
    echo -e "${YELLOW}⚠️  STUN 已在运行${NC}"
    return 0
  fi
  echo "启动 STUN..."
  nohup sudo $TURN_BIN -c $TURN_CONF > /tmp/turn.log 2>&1 &
  sleep 2
  if pgrep -f "turnserver -c $TURN_CONF" > /dev/null; then
    echo -e "${GREEN}✅ STUN 启动成功 (PID: $(pgrep -f "turnserver -c $TURN_CONF"))${NC}"
  else
    echo -e "${RED}❌ STUN 启动失败，查看日志: cat /tmp/turn.log${NC}"
    return 1
  fi
}

stop_stun() {
  if pgrep -f "turnserver -c $TURN_CONF" > /dev/null; then
    sudo pkill -f "turnserver -c $TURN_CONF"
    sleep 1
    echo -e "${GREEN}✅ STUN 已停止${NC}"
  else
    echo -e "${YELLOW}⚠️  STUN 未运行${NC}"
  fi
}

status_stun() {
  if pgrep -f "turnserver -c $TURN_CONF" > /dev/null; then
    PID=$(pgrep -f "turnserver -c $TURN_CONF")
    echo -e "STUN:    ${GREEN}运行中${NC} (PID: $PID)"
  else
    echo -e "STUN:    ${RED}未运行${NC}"
  fi
}

# ===== 信令服务 =====
start_signaling() {
  if ! check_signaling_bin; then return 1; fi
  if pgrep -f "$SIGNALING_PATTERN" > /dev/null; then
    echo -e "${YELLOW}⚠️  信令服务器已在运行${NC}"
    return 0
  fi
  echo "启动信令服务器..."
  cd $SIGNALING_DIR
  nohup ./$SIGNALING_NAME > /tmp/signaling.log 2>&1 &
  sleep 2
  if pgrep -f "$SIGNALING_PATTERN" > /dev/null; then
    echo -e "${GREEN}✅ 信令服务器启动成功 (PID: $(pgrep -f "$SIGNALING_PATTERN"))${NC}"
  else
    echo -e "${RED}❌ 信令服务器启动失败，查看日志: cat /tmp/signaling.log${NC}"
    return 1
  fi
}

stop_signaling() {
  if pgrep -f "$SIGNALING_PATTERN" > /dev/null; then
    sudo pkill -f "$SIGNALING_PATTERN"
    sleep 1
    echo -e "${GREEN}✅ 信令服务器已停止${NC}"
  else
    echo -e "${YELLOW}⚠️  信令服务器未运行${NC}"
  fi
}

status_signaling() {
  if pgrep -f "$SIGNALING_PATTERN" > /dev/null; then
    PID=$(pgrep -f "$SIGNALING_PATTERN")
    echo -e "信令服务: ${GREEN}运行中${NC} (PID: $PID)"
  else
    echo -e "信令服务: ${RED}未运行${NC}"
  fi
}

# ===== 端口检查 =====
check_ports() {
  echo ""
  echo "===== 端口监听 ====="
  if sudo ss -tln 2>/dev/null | grep -q ":8080"; then
    echo -e "  8080 (信令): ${GREEN}TCP 监听中${NC}"
  else
    echo -e "  8080 (信令): ${RED}未监听${NC}"
  fi
  if sudo ss -uln 2>/dev/null | grep -q ":3478"; then
    echo -e "  3478 (STUN):  ${GREEN}UDP 监听中${NC}"
  else
    echo -e "  3478 (STUN):  ${RED}未监听${NC}"
  fi
}

# ===== 主逻辑 =====
case "$1" in
  start)
    echo "===== 启动所有服务 ====="
    start_stun
    start_signaling
    check_ports
    ;;
  stop)
    echo "===== 停止所有服务 ====="
    stop_signaling
    stop_stun
    ;;
  restart)
    echo "===== 重启所有服务 ====="
    stop_signaling
    stop_stun
    sleep 1
    start_stun
    start_signaling
    check_ports
    ;;
  status)
    echo "===== 服务状态 ====="
    status_stun
    status_signaling
    check_ports
    ;;
  logs)
    case "$2" in
      stun|s|turn)
        echo "===== STUN 日志（Ctrl+C 退出）====="
        tail -f /tmp/turn.log
        ;;
      sig|signaling|signal)
        echo "===== 信令日志（Ctrl+C 退出）====="
        tail -f /tmp/signaling.log
        ;;
      *)
        echo "用法: $0 logs {stun|sig}"
        ;;
    esac
    ;;
  *)
    echo "用法: $0 {start|stop|restart|status|logs}"
    echo ""
    echo "示例:"
    echo "  $0 start       # 启动所有服务"
    echo "  $0 stop        # 停止所有服务"
    echo "  $0 restart     # 重启所有服务"
    echo "  $0 status      # 查看状态"
    echo "  $0 logs stun   # 查看 STUN 日志"
    echo "  $0 logs sig    # 查看信令日志"
    exit 1
    ;;
esac
