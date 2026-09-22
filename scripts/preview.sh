#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${PREVIEW_PID_FILE:-/tmp/cjtz-preview.pid}"
LOG_FILE="${PREVIEW_LOG_FILE:-/tmp/cjtz-preview.log}"
HOST="${PREVIEW_HOST:-0.0.0.0}"
PORT="${PREVIEW_PORT:-8000}"

lan_ip() {
    hostname -I 2>/dev/null | tr ' ' '\n' | awk '
        $1 ~ /^10\./ ||
        $1 ~ /^192\.168\./ ||
        $1 ~ /^172\.(1[6-9]|2[0-9]|3[0-1])\./ { print $1; exit }
    '
}

print_urls() {
    echo "URL: http://localhost:${PORT}/"
    local ip
    ip="$(lan_ip)"
    if [[ -n "$ip" ]]; then
        echo "LAN URL: http://${ip}:${PORT}/"
    else
        echo "LAN URL: unable to detect a private IPv4 address"
    fi
}

is_running() {
    [[ -f "$PID_FILE" ]] || return 1
    local pid
    pid="$(<"$PID_FILE")"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    ps -p "$pid" -o args= 2>/dev/null | grep -Fq 'http.server'
}

start() {
    if is_running; then
        echo "Preview server is already running (PID $(<"$PID_FILE"))"
        print_urls
        return 0
    fi

    rm -f "$PID_FILE"
    nohup python3 -m http.server "$PORT" --bind "$HOST" --directory "$ROOT_DIR" \
        >>"$LOG_FILE" 2>&1 &
    echo $! >"$PID_FILE"

    sleep 0.2
    if ! is_running; then
        echo "Failed to start preview server. See $LOG_FILE" >&2
        rm -f "$PID_FILE"
        return 1
    fi

    echo "Preview server started (PID $(<"$PID_FILE"))"
    print_urls
    echo "Log: $LOG_FILE"
}

stop() {
    if ! is_running; then
        echo "Preview server is not running"
        rm -f "$PID_FILE"
        return 0
    fi

    local pid
    pid="$(<"$PID_FILE")"
    kill "$pid"
    rm -f "$PID_FILE"
    echo "Preview server stopped"
}

status() {
    if is_running; then
        echo "Preview server is running (PID $(<"$PID_FILE"))"
        print_urls
    else
        echo "Preview server is not running"
        return 1
    fi
}

case "${1:-start}" in
    start) start ;;
    stop) stop ;;
    restart) stop || true; start ;;
    status) status ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}" >&2
        exit 2
        ;;
esac
