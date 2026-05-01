#!/bin/bash
# CC Clip — 启动/停止/管理菜单栏浮窗

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SCRIPT="$SCRIPT_DIR/cc-clipboard.py"
PID_FILE="/tmp/cc-clipboard.pid"

case "${1:-start}" in
  start)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "CC Clip 已在运行 (PID $(cat "$PID_FILE"))"
      exit 0
    fi
    nohup python3 "$APP_SCRIPT" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    echo "CC Clip 已启动 (PID $!)"
    ;;
  stop)
    if [ ! -f "$PID_FILE" ]; then
      echo "未找到 PID 文件"
      pkill -f "cc-clipboard.py" 2>/dev/null && echo "已停止" || echo "未运行"
      exit 0
    fi
    PID=$(cat "$PID_FILE")
    kill "$PID" 2>/dev/null && echo "已停止" || echo "停止失败（PID $PID 不存在）"
    rm -f "$PID_FILE"
    pkill -f "cc-clipboard.py" 2>/dev/null  # clean up any orphans
    ;;
  restart)
    "$0" stop; sleep 1; "$0" start
    ;;
  status)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "CC Clip 运行中 (PID $(cat "$PID_FILE"))"
    elif pkill -0 -f "cc-clipboard.py" 2>/dev/null; then
      echo "CC Clip 运行中（无 PID 文件）"
    else
      echo "CC Clip 未运行"
    fi
    ;;
  autostart)
    PLIST="$HOME/Library/LaunchAgents/com.ccclipboard.plist"
    if [ ! -f "$PLIST" ]; then
      cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ccclipboard</string>
    <key>Program</key>
    <string>$(command -v python3)</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(command -v python3)</string>
        <string>${APP_SCRIPT}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${PATH}</string>
    </dict>
</dict>
</plist>
EOF
      echo "已创建 LaunchAgent: $PLIST"
      launchctl load "$PLIST"
      echo "已加载 LaunchAgent（登录时自动启动）"
    else
      echo "LaunchAgent 已存在: $PLIST"
    fi
    ;;
  noautostart)
    PLIST="$HOME/Library/LaunchAgents/com.ccclipboard.plist"
    if [ -f "$PLIST" ]; then
      launchctl unload "$PLIST" 2>/dev/null
      rm "$PLIST"
      echo "已移除 LaunchAgent"
    else
      echo "LaunchAgent 不存在"
    fi
    ;;
  *)
    echo "用法: $0 {start|stop|restart|status|autostart|noautostart}"
    exit 1
    ;;
esac
