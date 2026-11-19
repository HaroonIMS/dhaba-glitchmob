#!/usr/bin/env bash
# Checks the cluster: node readiness, crashing pods, node CPU and memory,
# persistent volume claims, and warning events.
# Prints OK / WARN / FAIL lines and exits 1 if any check fails.
# Usage: check-cluster.sh [context]   (no argument inside the cluster)
set -uo pipefail

CONTEXT="${1:-}"
K="kubectl ${CONTEXT:+--context $CONTEXT}"
FAILURES=0

ok()   { echo "OK    $*"; }
warn() { echo "WARN  $*"; }
fail() { echo "FAIL  $*"; FAILURES=$((FAILURES + 1)); }

# 1. Nodes that are not Ready
NOT_READY=$($K get nodes --no-headers 2>/dev/null | awk '$2 != "Ready" {print $1}')
if [[ -z "$($K get nodes --no-headers 2>/dev/null)" ]]; then
  fail "cluster unreachable or no nodes"
elif [[ -z "$NOT_READY" ]]; then
  ok "all nodes Ready"
else
  fail "nodes not Ready: $(echo $NOT_READY | tr '\n' ' ')"
fi

# 2. Pods that are crashing, can't pull an image, or keep restarting
BAD_PODS=$($K get pods -A --no-headers 2>/dev/null | awk '
  $4 ~ /CrashLoopBackOff|ImagePullBackOff|ErrImagePull|CreateContainerConfigError|Error/ {print $1"/"$2" ("$4")"}
  $5+0 >= 5 && $4 == "Running" {print $1"/"$2" (restarts="$5")"}')
if [[ -z "$BAD_PODS" ]]; then
  ok "no crashing or stuck pods"
else
  fail "problem pods: $(echo $BAD_PODS | tr '\n' ' ')"
fi

# 3. Node CPU and memory (needs metrics-server)
if TOP=$($K top nodes --no-headers 2>/dev/null) && [[ -n "$TOP" ]]; then
  while read -r name cpu cpu_pct mem mem_pct; do
    cpu_pct=${cpu_pct%\%}; mem_pct=${mem_pct%\%}
    if (( cpu_pct >= 90 || mem_pct >= 90 )); then
      fail "$name high use: cpu ${cpu_pct}% mem ${mem_pct}%"
    elif (( cpu_pct >= 75 || mem_pct >= 75 )); then
      warn "$name busy: cpu ${cpu_pct}% mem ${mem_pct}%"
    else
      ok "$name cpu ${cpu_pct}% mem ${mem_pct}%"
    fi
  done <<< "$TOP"
else
  warn "node metrics unavailable (metrics-server not installed)"
fi

# 4. Persistent volume claims that are not Bound
PVC_BAD=$($K get pvc -A --no-headers 2>/dev/null | awk '$3 != "Bound" {print $1"/"$2" ("$3")"}')
if [[ -z "$PVC_BAD" ]]; then
  ok "all persistent volume claims Bound"
else
  fail "unbound volumes: $(echo $PVC_BAD | tr '\n' ' ')"
fi

# 5. Warning events
WARNINGS=$($K get events -A --field-selector type=Warning --no-headers 2>/dev/null | wc -l)
if (( WARNINGS == 0 )); then
  ok "no warning events"
else
  warn "$WARNINGS warning event(s) in the cluster"
fi

if (( FAILURES > 0 )); then
  echo "RESULT: $FAILURES check(s) failed"
  exit 1
fi
echo "RESULT: no failures"
