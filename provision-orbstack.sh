#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_HOME=/home/agent/agent-app

[ "$EUID" -eq 0 ] && [ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || {
    echo '[ERROR] run with sudo inside an amd64 Linux VM' >&2
    exit 1
}

missing=0
for command_name in pgrep ps awk getconf runuser; do
    command -v "$command_name" >/dev/null 2>&1 || missing=1
done
if [ "$missing" -eq 1 ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y procps gawk coreutils util-linux
fi

if ! id agent >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash agent
fi
[ "$(id -u agent)" -ne 0 ] || { echo '[ERROR] agent must not be root' >&2; exit 1; }
agent_group=$(id -gn agent)
install -d -o agent -g "$agent_group" -m 755 "$AGENT_HOME" "$AGENT_HOME/bin" "$AGENT_HOME/evidence"
install -o agent -g "$agent_group" -m 755 "$SCRIPT_DIR/agent-leak-app-x86" "$AGENT_HOME/bin/agent-leak-app"
for script in monitor.sh run-scenario.sh run-all-scenarios.sh setup-agent-env.sh verify-results.sh; do
    install -o agent -g "$agent_group" -m 755 "$SCRIPT_DIR/$script" "$AGENT_HOME/bin/$script"
done
runuser -u agent -- env AGENT_HOME="$AGENT_HOME" bash "$AGENT_HOME/bin/setup-agent-env.sh"
printf '[provision] ready: user=agent home=%s\n' "$AGENT_HOME"
