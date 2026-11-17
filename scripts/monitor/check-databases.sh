#!/usr/bin/env bash
# Checks Postgres and Redis in each environment.
# Prints one line per check and exits 1 if any check fails.
# Usage: check-databases.sh [context] [namespaces...]
set -uo pipefail

CONTEXT="${1:-glitchmob-shared}"
shift || true
NAMESPACES="${*:-staging production}"
FAILURES=0

ok()   { echo "OK    $*"; }
fail() { echo "FAIL  $*"; FAILURES=$((FAILURES + 1)); }

for ns in $NAMESPACES; do
  K="kubectl --context $CONTEXT -n $ns"

  # Postgres: accepts connections
  if $K exec postgres-0 -- pg_isready -U dhaba >/dev/null 2>&1; then
    ok "$ns postgres accepting connections"
  else
    fail "$ns postgres not accepting connections"
  fi

  # Postgres: open connections and database size
  CONNS=$($K exec postgres-0 -- psql -U dhaba -d dhaba -tAc \
    "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null)
  if [[ "$CONNS" =~ ^[0-9]+$ ]]; then
    ok "$ns postgres open connections: $CONNS"
  else
    fail "$ns postgres could not count connections"
  fi

  SIZE=$($K exec postgres-0 -- psql -U dhaba -d dhaba -tAc \
    "SELECT pg_size_pretty(pg_database_size('dhaba'));" 2>/dev/null)
  if [[ -n "$SIZE" ]]; then
    ok "$ns postgres database size: $SIZE"
  else
    fail "$ns postgres could not read database size"
  fi

  # Postgres: volume fill (percent used on the data mount)
  VOL=$($K exec postgres-0 -- df -P /var/lib/postgresql/data 2>/dev/null | awk 'NR==2 {print $5}')
  if [[ -n "$VOL" ]]; then
    ok "$ns postgres volume used: $VOL"
  else
    fail "$ns postgres could not read volume usage"
  fi

  # Redis: answers
  if [[ "$($K exec redis-0 -- redis-cli ping 2>/dev/null)" == "PONG" ]]; then
    ok "$ns redis answering"
  else
    fail "$ns redis not answering"
  fi

  # Redis: memory used
  MEM=$($K exec redis-0 -- redis-cli INFO memory 2>/dev/null | tr -d '\r' | awk -F: '/^used_memory_human/ {print $2}')
  if [[ -n "$MEM" ]]; then
    ok "$ns redis memory used: $MEM"
  else
    fail "$ns redis could not read memory"
  fi

  # Redis: last successful save to disk
  SAVE=$($K exec redis-0 -- redis-cli LASTSAVE 2>/dev/null | tr -d '\r')
  if [[ "$SAVE" =~ ^[0-9]+$ ]]; then
    ok "$ns redis last save (unix time): $SAVE"
  else
    fail "$ns redis could not read last save"
  fi

  # Redis: connected clients
  CLIENTS=$($K exec redis-0 -- redis-cli INFO clients 2>/dev/null | tr -d '\r' | awk -F: '/^connected_clients/ {print $2}')
  if [[ -n "$CLIENTS" ]]; then
    ok "$ns redis connected clients: $CLIENTS"
  else
    fail "$ns redis could not read client count"
  fi
done

if [[ $FAILURES -gt 0 ]]; then
  echo "RESULT: $FAILURES check(s) failed"
  exit 1
fi
echo "RESULT: all checks passed"
