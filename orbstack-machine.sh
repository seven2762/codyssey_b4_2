#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACHINE_NAME="${MACHINE_NAME:-b1-2-agent}"
ORB_BIN="${ORB_BIN:-orb}"
AGENT_HOME=/home/agent/agent-app
ACTION="${1:---help}"

usage() {
    cat <<EOF
Usage: $0 [provision|run-all|verify|collect|demo]
  provision  Create/start amd64 Ubuntu and prepare the non-root agent account
  run-all    Run the six required Before/After scenarios
  verify     Check boot logs, settings and collected evidence
  collect    Copy the six evidence folders into this repository
  demo       provision -> run-all -> verify -> collect
Environment: MACHINE_NAME (default: b1-2-agent)
EOF
}

case "$ACTION" in
    -h|--help) usage; exit 0 ;;
    provision|run-all|verify|collect|demo) ;;
    *) usage >&2; exit 1 ;;
esac
[[ "$MACHINE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
    echo '[ERROR] unsafe machine name' >&2
    exit 1
}
command -v "$ORB_BIN" >/dev/null 2>&1 || { echo '[ERROR] OrbStack CLI not found' >&2; exit 1; }

run_vm() { "$ORB_BIN" -m "$MACHINE_NAME" "$@"; }

start_vm() {
    if ! "$ORB_BIN" list | awk '$1 != "NAME" {print $1}' | grep -Fxq "$MACHINE_NAME"; then
        "$ORB_BIN" create --arch amd64 ubuntu:noble "$MACHINE_NAME"
    fi
    "$ORB_BIN" start "$MACHINE_NAME"
}

provision() {
    local staging result=0
    # Transfer through stdin: macOS Desktop sharing can block reads in the VM.
    staging=$(run_vm mktemp -d /tmp/b1-2-provision.XXXXXX)
    [[ "$staging" =~ ^/tmp/b1-2-provision\.[A-Za-z0-9]+$ ]] || return 1
    if COPYFILE_DISABLE=1 tar --no-xattrs -C "$SCRIPT_DIR" -cf - agent-leak-app-x86 \
        monitor.sh run-scenario.sh run-all-scenarios.sh setup-agent-env.sh \
        verify-results.sh provision-orbstack.sh | run_vm tar -C "$staging" -xf -; then
        run_vm sudo bash "$staging/provision-orbstack.sh" || result=$?
    else
        result=1
    fi
    run_vm rm -rf -- "$staging"
    return "$result"
}

run_all() {
    run_vm sudo -u agent -H env "AGENT_HOME=$AGENT_HOME" bash "$AGENT_HOME/bin/run-all-scenarios.sh"
}

verify() {
    run_vm sudo -u agent -H env "EVIDENCE_ROOT=$AGENT_HOME/evidence" bash "$AGENT_HOME/bin/verify-results.sh"
}

collect() {
    run_vm sudo tar -C "$AGENT_HOME" -cf - \
        evidence/oom_before evidence/oom_after evidence/cpu_before evidence/cpu_after \
        evidence/deadlock_before evidence/deadlock_after | tar -C "$SCRIPT_DIR" -xf -
}

start_vm
case "$ACTION" in
    provision) provision ;;
    run-all) run_all ;;
    verify) verify ;;
    collect) collect ;;
    demo) provision; run_all; verify; collect ;;
esac
