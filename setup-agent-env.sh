#!/usr/bin/env bash
set -euo pipefail
umask 077

AGENT_HOME="${AGENT_HOME:-/home/agent/agent-app}"
ENV_FILE="${ENV_FILE:-$AGENT_HOME/.env}"

[[ "$AGENT_HOME" = /* ]] || { echo '[ERROR] AGENT_HOME must be an absolute path' >&2; exit 1; }
[ "${AGENT_PORT:-15034}" = 15034 ] || { echo '[ERROR] AGENT_PORT must be 15034' >&2; exit 1; }

mkdir -p "$AGENT_HOME/upload_files" "$AGENT_HOME/api_keys" "$AGENT_HOME/logs"
chmod 755 "$AGENT_HOME" "$AGENT_HOME/upload_files" "$AGENT_HOME/logs"
chmod 700 "$AGENT_HOME/api_keys"
key="$AGENT_HOME/api_keys/secret.key"
if [ ! -e "$key" ]; then
    printf '%s\n' 'agent_api_key_test' > "$key"
fi
[ "$(cat "$key")" = agent_api_key_test ] || {
    echo '[ERROR] existing secret.key must contain agent_api_key_test' >&2
    exit 1
}
chmod 600 "$key"

mkdir -p "$(dirname "$ENV_FILE")"
{
    printf 'export AGENT_HOME=%q\n' "$AGENT_HOME"
    printf 'export AGENT_PORT=15034\n'
    printf 'export AGENT_UPLOAD_DIR=%q\n' "$AGENT_HOME/upload_files"
    printf 'export AGENT_KEY_PATH=%q\n' "$AGENT_HOME/api_keys"
    printf 'export AGENT_LOG_DIR=%q\n' "$AGENT_HOME/logs"
} > "$ENV_FILE"
chmod 600 "$ENV_FILE"
printf '[setup-agent-env] ready: source %q\n' "$ENV_FILE"
