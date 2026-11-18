#!/usr/bin/env bash
# Checks application services, worker heartbeat, and Redis queue.
# Usage: check-services.sh [context] [namespaces...]
# Without a context, uses in-cluster ServiceAccount authentication.

set -uo pipefail

CONTEXT="${KUBECTL_CONTEXT:-}"

if [[ $# -gt 0 && "$1" != "staging" && "$1" != "production" ]]; then
  CONTEXT="$1"
  shift
fi

NAMESPACES=("$@")
if [[ ${#NAMESPACES[@]} -eq 0 ]]; then
  NAMESPACES=(staging production)
fi

K=(kubectl)
if [[ -n "$CONTEXT" ]]; then
  K+=(--context "$CONTEXT")
fi

SERVICES=(web menu-api orders-api stats-api)
FAILURES=0

ok()   { echo "OK    $*"; }
warn() { echo "WARN  $*"; }
fail() { echo "FAIL  $*"; FAILURES=$((FAILURES + 1)); }

for ns in "${NAMESPACES[@]}"; do

  echo "----- $ns service checks -----"

  for svc in "${SERVICES[@]}"; do

    # Check whether the Deployment exists
    if ! "${K[@]}" -n "$ns" get deployment "$svc" >/dev/null 2>&1; then
      warn "$ns $svc NOT DEPLOYED"
      continue
    fi

    # Check service health from inside the monitoring container
if ! "${K[@]}" -n "$ns" get service "$svc" >/dev/null 2>&1; then
  fail "$ns $svc Deployment exists but Service is missing"
  continue
fi

# Prefer a Service port named http; otherwise use its first port.
PORT=$("${K[@]}" -n "$ns" get service "$svc" \
  -o jsonpath='{.spec.ports[?(@.name=="http")].port}' 2>/dev/null)

if [[ -z "$PORT" ]]; then
  PORT=$("${K[@]}" -n "$ns" get service "$svc" \
    -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
fi

if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
  fail "$ns $svc Service has no usable port"
  continue
fi

OUT=$(curl -sS --connect-timeout 3 --max-time 10 \
  -o /dev/null -w "%{http_code} %{time_total}" \
  "http://$svc.$ns.svc.cluster.local:$PORT/health" 2>/dev/null) || true

CODE=${OUT%% *}
TIME=${OUT##* }

if [[ "$CODE" == "200" ]]; then
  if awk "BEGIN{exit !($TIME > 1.0)}"; then
    warn "$ns $svc healthy but slow: ${TIME}s"
  else
    ok "$ns $svc healthy (${TIME}s)"
  fi
else
  fail "$ns $svc health check returned '${CODE:-no response}'"
fi

done

  # Check worker heartbeat
  if "${K[@]}" -n "$ns" get deployment kitchen-worker >/dev/null 2>&1; then

    BEAT=$("${K[@]}" -n "$ns" exec redis-0 -- \
      redis-cli TTL worker:heartbeat 2>/dev/null | tr -d '\r') || true

    if [[ "$BEAT" =~ ^[0-9]+$ ]] && (( BEAT > 0 )); then
      ok "$ns kitchen-worker heartbeat present"
    else
      fail "$ns kitchen-worker heartbeat missing"
    fi

  else
    warn "$ns kitchen-worker NOT DEPLOYED"
  fi

  # Check Redis job queue length
  QLEN=$("${K[@]}" -n "$ns" exec redis-0 -- \
    redis-cli LLEN orders:queue 2>/dev/null | tr -d '\r') || true

  if [[ "$QLEN" =~ ^[0-9]+$ ]]; then
    ok "$ns job queue length: $QLEN"
  else
    warn "$ns job queue length unavailable"
  fi

done


if (( FAILURES > 0 )); then
  echo "RESULT: $FAILURES check(s) failed"
  exit 1
fi
echo "RESULT: no failures among deployed services"
