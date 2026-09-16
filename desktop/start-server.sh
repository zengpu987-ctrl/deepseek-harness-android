#!/bin/bash
#
# start-server.sh — make sure an app-owned `dsh web` instance is running and print
# its authenticated URL as the single stdout line `URL=<url>`.
#
# Called by the DeepSeek Harness window (DSHWindow.swift). Diagnostics go to the
# launcher log; failures go to stderr with a non-zero exit status.
#
# Why the token matters: the GUI only accepts a URL carrying the per-process launch
# token (which also plants the HttpOnly session cookie). A bare
# http://127.0.0.1:PORT request is answered with 401, and the token of a `dsh web`
# started elsewhere (for example in a terminal) cannot be recovered — so this script
# reuses only instances it started itself, and otherwise starts its own on the first
# free port.
#
# Overrides:
#   DSH_WEB_PORT   first port to try (default: 3080)
#   DSH_BIN        explicit path to the dsh executable

set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUPPORT_DIR="$HOME/Library/Application Support/DeepSeek Harness"
LOG_DIR="$HOME/Library/Logs/DeepSeek Harness"
WEB_LOG="$LOG_DIR/dsh-web.log"
LAUNCH_LOG="$LOG_DIR/launcher.log"
STATE_FILE="$SUPPORT_DIR/instance.env"
CONFIG_FILE="$SUPPORT_DIR/config.env"
LOCK_DIR="$SUPPORT_DIR/launch.lock"
PORT_SCAN_LIMIT=20
LOCK_STALE_SECONDS=180

# Optional user configuration, e.g. DSH_WEB_PORT=8080 or DSH_BIN=/path/to/dsh.
if [ -f "$CONFIG_FILE" ]; then
	# shellcheck disable=SC1090
	. "$CONFIG_FILE"
fi

BASE_PORT="${DSH_WEB_PORT:-3080}"
LOCK_HELD=0

export PATH="$HOME/bin:$HOME/nodejs/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

mkdir -p "$SUPPORT_DIR" "$LOG_DIR" 2>/dev/null || true

log() {
	printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LAUNCH_LOG" 2>/dev/null || true
}

state_get() {
	[ -f "$STATE_FILE" ] || return 0
	/usr/bin/sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}

port_in_use() {
	/usr/sbin/lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1 && return 0
	/usr/bin/nc -z -G 2 -w 2 127.0.0.1 "$1" >/dev/null 2>&1 && return 0
	return 1
}

# A launch-token URL answers 303 while its process lives; a stale one answers 401.
url_accepts() {
	local code
	code="$(/usr/bin/curl -sS -m 5 -o /dev/null -w '%{http_code}' "$1" 2>/dev/null || true)"
	[ "$code" = "303" ]
}

find_dsh() {
	local c
	if [ -n "${DSH_BIN:-}" ] && [ -x "${DSH_BIN}" ]; then
		printf '%s' "$DSH_BIN"
		return 0
	fi
	for c in "$HOME/bin/dsh" "$HOME/nodejs/bin/dsh" /opt/homebrew/bin/dsh /usr/local/bin/dsh; do
		if [ -x "$c" ]; then
			printf '%s' "$c"
			return 0
		fi
	done
	c="$(command -v dsh 2>/dev/null || true)"
	if [ -n "$c" ] && [ -x "$c" ]; then
		printf '%s' "$c"
		return 0
	fi
	return 1
}

# Serialize launches so two clicks cannot start two servers.
acquire_lock() {
	if mkdir "$LOCK_DIR" 2>/dev/null; then
		LOCK_HELD=1
		return 0
	fi
	local now age
	now="$(date +%s)"
	age="$(/usr/bin/stat -f %m "$LOCK_DIR" 2>/dev/null || printf '%s' "$now")"
	if [ $((now - age)) -gt "$LOCK_STALE_SECONDS" ]; then
		log "removing a stale launch lock"
		rmdir "$LOCK_DIR" 2>/dev/null || true
		if mkdir "$LOCK_DIR" 2>/dev/null; then
			LOCK_HELD=1
			return 0
		fi
	fi
	return 1
}

release_lock() {
	if [ "$LOCK_HELD" = "1" ]; then
		rmdir "$LOCK_DIR" 2>/dev/null || true
		LOCK_HELD=0
	fi
	return 0
}

live_url() {
	local url
	url="$(state_get url)"
	if [ -n "$url" ] && url_accepts "$url"; then
		printf '%s' "$url"
		return 0
	fi
	return 1
}

wait_for_live_state() {
	local seconds="$1" url
	for _ in $(/usr/bin/seq 1 "$seconds"); do
		if url="$(live_url)"; then
			printf '%s' "$url"
			return 0
		fi
		sleep 1
	done
	return 1
}

log "server requested by the app (base port $BASE_PORT)"

if URL="$(live_url)"; then
	log "reusing running instance (port $(state_get port), pid $(state_get pid))"
	printf 'URL=%s\n' "$URL"
	exit 0
fi

if ! acquire_lock; then
	log "another launch is already in progress"
	if URL="$(wait_for_live_state 90)"; then
		log "reusing the instance that launch produced: $URL"
		printf 'URL=%s\n' "$URL"
		exit 0
	fi
	echo "另一个 DeepSeek Harness 启动过程仍在进行中，请稍后重试。" >&2
	exit 1
fi
trap release_lock EXIT

if URL="$(live_url)"; then
	printf 'URL=%s\n' "$URL"
	exit 0
fi

PORT=""
if [ -n "${DSH_WEB_PORT:-}" ]; then
	CANDIDATES="$BASE_PORT"
else
	CANDIDATES="$(/usr/bin/seq "$BASE_PORT" $((BASE_PORT + PORT_SCAN_LIMIT - 1)))"
fi
for candidate in $CANDIDATES; do
	if ! port_in_use "$candidate"; then
		PORT="$candidate"
		break
	fi
	log "port $candidate is busy; trying the next one"
done

if [ -z "$PORT" ]; then
	echo "从 $BASE_PORT 起的 $PORT_SCAN_LIMIT 个端口都被占用了。请先释放端口，或用环境变量 DSH_WEB_PORT 指定其他端口。" >&2
	exit 1
fi

DSH_PATH="$(find_dsh)" || {
	echo "找不到 dsh 命令。请确认已安装 DSH CLI（例如 $HOME/nodejs/bin/dsh），或用 DSH_BIN 指定路径。" >&2
	exit 1
}

LAN_IP="$(/sbin/ifconfig en0 2>/dev/null | /usr/bin/awk '/inet /{print $2}' | /usr/bin/head -n1)"
CF_HOST="$(/usr/bin/grep -ao 'https://[a-z0-9-]*\.trycloudflare\.com' "$HOME/.dsh/cloudflared.err" 2>/dev/null | /usr/bin/head -n1 | /usr/bin/sed 's#https://##')"
TRUST_ARGS=""
if [ -n "$LAN_IP" ]; then
	TRUST_ARGS="--trusted-host $LAN_IP --trusted-host $LAN_IP:3082"
fi
if [ -n "$CF_HOST" ]; then
	TRUST_ARGS="$TRUST_ARGS --trusted-host $CF_HOST"
fi

: >"$WEB_LOG"
trap '' HUP
/usr/bin/nohup "$DSH_PATH" web --port "$PORT" $TRUST_ARGS --no-open >>"$WEB_LOG" 2>&1 &
SERVER_PID=$!
disown "$SERVER_PID" 2>/dev/null || true
log "started: $DSH_PATH web --port $PORT --no-open (pid $SERVER_PID)"

# Accept only the URL line for the port we started, so concurrent writers of the
# shared log can never hand us somebody else's token.
URL=""
for _ in $(/usr/bin/seq 1 240); do
	if ! kill -0 "$SERVER_PID" 2>/dev/null; then
		rm -f "$STATE_FILE"
		echo "dsh web 启动失败，日志 $WEB_LOG 末尾：" >&2
		tail -n 8 "$WEB_LOG" 2>/dev/null >&2
		exit 1
	fi
	URL="$(/usr/bin/grep -oE '^dsh web: [^ ]+' "$WEB_LOG" 2>/dev/null | /usr/bin/awk '{print $3}' | /usr/bin/grep -m1 ":$PORT/" || true)"
	[ -n "$URL" ] && break
	sleep 1
done

if [ -n "$URL" ] && url_accepts "$URL"; then
	{
		printf 'port=%s\n' "$PORT"
		printf 'pid=%s\n' "$SERVER_PID"
		printf 'url=%s\n' "$URL"
	} >"$STATE_FILE"
	log "ready: $URL"
	printf 'URL=%s\n' "$URL"
	exit 0
fi

kill "$SERVER_PID" 2>/dev/null || true
rm -f "$STATE_FILE"
echo "DeepSeek Harness 启动超时，日志：$WEB_LOG" >&2
tail -n 8 "$WEB_LOG" 2>/dev/null >&2
exit 1
