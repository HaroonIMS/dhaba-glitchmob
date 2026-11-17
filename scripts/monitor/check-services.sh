#!/usr/bin/env bash
# Checks the application services in each environment:
# health endpoint, response time, worker heartbeat, and queue length.
# A service with no Deployment is reported as NOT DEPLOYED, not as a failure.
# Prints one line per check and exits 1 if any deployed service fails.
# Usage: check-services.sh [context] [namespaces...]
set -uo pipefail

CONTEXT="${1:-glitchmob-shared}"
shift || true
NAMESPACES="${*:-staging production}"
SERVICES="web menu-api orders-api stats-api"
FAILURES=0

ok()   { echo "OK    $*"; }
warn() { echo "WARN  $*"; }
fail() { echo "FAIL  $*"; FAILURES=$((FAILURES + 1)); }

for ns in $NAMESPACES; do
  K="kubectl --context $CONTEXT -n $ns"

  for svc in $SERVICES; do
    # Is there a Deployment for this service?
    if ! $K get deployment "$svc" >/dev/null 2>&1; then
      warn "$ns $svc NOT DEPLOYED"
      continue
    fi

    # Health endpoint, through the in-cluster Service, with timing
    OUT=$($K run "probe-$svc-$RANDOM" --rm -i --restart=Never --quiet \
      --image=curlimages/curl:8.10.1 -- \
      curl -s -o /dev/null -w "%{http_code} %{time_total}" \
      "http://$svc.$ns.svc.cluster.local/health" 2>/dev/null)
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

  # Worker heartbeat: the starter code writes it to Redis every 10 seconds
  if $K get deployment kitchen-worker >/dev/null 2>&1; then
    BEAT=$($K exec redis-0 -- redis-cli TTL worker:heartbeat 2>/dev/null | tr -d '\r')
    if [[ "$BEAT" =~ ^-?[0-9]+$ ]] && (( BEAT > 0 )); then
      ok "$ns kitchen-worker heartbeat present"
    else
      fail "$ns kitchen-worker heartbeat missing"
    fi
  else
    warn "$ns kitchen-worker NOT DEPLOYED"
  fi

  # Job queue length (alert if it keeps growing across runs)
  QLEN=$($K exec redis-0 -- redis-cli LLEN orders:queue 2>/dev/null | tr -d '\r')
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
