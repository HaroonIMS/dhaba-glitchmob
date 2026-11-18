#!/usr/bin/env bash
# Checks PostgreSQL and Redis in each environment.
# Usage: check-databases.sh [context] [namespaces...]
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

FAILURES=0

ok()   { echo "OK    $*"; }
fail() { echo "FAIL  $*"; FAILURES=$((FAILURES + 1)); }

for ns in "${NAMESPACES[@]}"; do

  echo "----- $ns database checks -----"

  # PostgreSQL: accepts connections
  if "${K[@]}" -n "$ns" exec postgres-0 -- pg_isready -U dhaba >/dev/null 2>&1; then
    ok "$ns postgres accepting connections"
  else
    fail "$ns postgres not accepting connections"
  fi

  # PostgreSQL: open connections
  CONNS=$("${K[@]}" -n "$ns" exec postgres-0 -- \
    psql -U dhaba -d dhaba -tAc \
    "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null) || true

  CONNS=$(echo "$CONNS" | tr -d '[:space:]')

  if [[ "$CONNS" =~ ^[0-9]+$ ]]; then
    ok "$ns postgres open connections: $CONNS"
  else
    fail "$ns postgres could not count connections"
  fi

  # PostgreSQL: database size
  SIZE=$("${K[@]}" -n "$ns" exec postgres-0 -- \
    psql -U dhaba -d dhaba -tAc \
    "SELECT pg_size_pretty(pg_database_size('dhaba'));" 2>/dev/null) || true

  SIZE=$(echo "$SIZE" | xargs)

  if [[ -n "$SIZE" ]]; then
    ok "$ns postgres database size: $SIZE"
  else
    fail "$ns postgres could not read database size"
  fi

  # PostgreSQL: persistent volume usage
  VOL=$("${K[@]}" -n "$ns" exec postgres-0 -- \
    df -P /var/lib/postgresql/data 2>/dev/null | awk 'NR==2 {print $5}') || true

  if [[ "$VOL" =~ ^[0-9]+%$ ]]; then
    ok "$ns postgres volume used: $VOL"
  else
    fail "$ns postgres could not read volume usage"
  fi

  # Redis: connectivity
  PING=$("${K[@]}" -n "$ns" exec redis-0 -- \
    redis-cli ping 2>/dev/null | tr -d '\r') || true

  if [[ "$PING" == "PONG" ]]; then
    ok "$ns redis answering"
  else
    fail "$ns redis not answering"
  fi

  # Redis: memory usage
  MEM=$("${K[@]}" -n "$ns" exec redis-0 -- \
    redis-cli INFO memory 2>/dev/null |
    tr -d '\r' | awk -F: '/^used_memory_human/ {print $2}') || true

  if [[ -n "$MEM" ]]; then
    ok "$ns redis memory used: $MEM"
  else
    fail "$ns redis could not read memory"
  fi

  # Redis: last successful save
  SAVE=$("${K[@]}" -n "$ns" exec redis-0 -- \
    redis-cli LASTSAVE 2>/dev/null | tr -d '\r') || true

  if [[ "$SAVE" =~ ^[0-9]+$ ]]; then
    ok "$ns redis last save (unix time): $SAVE"
  else
    fail "$ns redis could not read last save"
  fi

  # Redis: connected clients
  CLIENTS=$("${K[@]}" -n "$ns" exec redis-0 -- \
    redis-cli INFO clients 2>/dev/null |
    tr -d '\r' | awk -F: '/^connected_clients/ {print $2}') || true

  if [[ "$CLIENTS" =~ ^[0-9]+$ ]]; then
    ok "$ns redis connected clients: $CLIENTS"
  else
    fail "$ns redis could not read client count"
  fi

done

if (( FAILURES > 0 )); then
  echo "RESULT: $FAILURES check(s) failed"
  exit 1
fi

echo "RESULT: all checks passed"
