#!/usr/bin/env bash
# Runs all monitoring checks and sends Slack alerts on state changes.
# Sends a healthy summary every 30 minutes.
set -uo pipefail

NAMESPACE="ops"
CONFIGMAP="ops-monitor-state"
SUMMARY_INTERVAL=1800

if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
  echo "ERROR: SLACK_WEBHOOK_URL is not set"
  exit 1
fi

ok() { echo "OK    $*"; }
fail() { echo "FAIL  $*"; }

REPORT=""
OVERALL_FAILURES=0

run_check() {
  local name="$1"
  local script="$2"
  local output
  local rc

  echo "Running $name..."

  output=$("$script" 2>&1)
  rc=$?

  REPORT+=$'\n'"--- $name ---"$'\n'"$output"$'\n'

  if (( rc != 0 )); then
    OVERALL_FAILURES=$((OVERALL_FAILURES + 1))
    fail "$name reported a problem"
  else
    ok "$name completed"
  fi
}

run_check "Cluster checks" "/opt/monitor/check-cluster.sh"
run_check "Database checks" "/opt/monitor/check-databases.sh"
run_check "Service checks" "/opt/monitor/check-services.sh"

NOW=$(date +%s)

if (( OVERALL_FAILURES > 0 )); then
  NEW_STATE="FAIL"
else
  NEW_STATE="OK"
fi

if ! STATE_DATA=$(kubectl -n "$NAMESPACE" get configmap "$CONFIGMAP" \
  -o jsonpath='{.data.state}{"|"}{.data.last_summary}' 2>&1); then
  echo "ERROR: Could not read monitoring state from ConfigMap"
  echo "$STATE_DATA"
  exit 1
fi

PREVIOUS_STATE="${STATE_DATA%%|*}"
LAST_SUMMARY="${STATE_DATA#*|}"

if [[ "$PREVIOUS_STATE" != "OK" && "$PREVIOUS_STATE" != "FAIL" ]]; then
  echo "ERROR: Invalid monitoring state: $PREVIOUS_STATE"
  exit 1
fi

if [[ ! "$LAST_SUMMARY" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Invalid last_summary value: $LAST_SUMMARY"
  exit 1
fi

send_slack() {
  local message="$1"
  local payload

  payload=$(jq -n --arg text "$message" '{text: $text}')

  curl -fsS -X POST \
    -H "Content-Type: application/json" \
    --data "$payload" \
    "$SLACK_WEBHOOK_URL" >/dev/null
}

update_state() {
  local state="$1"
  local summary_time="$2"
  local patch

  patch=$(jq -n \
    --arg state "$state" \
    --arg summary "$summary_time" \
    '{data: {state: $state, last_summary: $summary}}')

  kubectl -n "$NAMESPACE" patch configmap "$CONFIGMAP" \
    --type merge -p "$patch" >/dev/null
}

if [[ "$NEW_STATE" == "FAIL" && "$PREVIOUS_STATE" != "FAIL" ]]; then

  MESSAGE="🚨 DhabaCart monitoring alert: problems detected.

$REPORT"

  echo "Sending failure alert to Slack..."

  if ! send_slack "$MESSAGE"; then
    echo "ERROR: Slack alert failed"
    exit 1
  fi

  if ! update_state "$NEW_STATE" "$LAST_SUMMARY"; then
    echo "ERROR: Could not update monitoring state in ConfigMap"
    exit 1
  fi

elif [[ "$NEW_STATE" == "OK" && "$PREVIOUS_STATE" == "FAIL" ]]; then

  MESSAGE="✅ DhabaCart monitoring recovery: all checks are passing again.

$REPORT"

  echo "Sending recovery notification to Slack..."

  if ! send_slack "$MESSAGE"; then
    echo "ERROR: Slack recovery notification failed"
    exit 1
  fi

  if ! update_state "$NEW_STATE" "$LAST_SUMMARY"; then
    echo "ERROR: Could not update monitoring state in ConfigMap"
    exit 1
  fi

elif [[ "$NEW_STATE" == "OK" ]]; then

  if (( NOW - LAST_SUMMARY >= SUMMARY_INTERVAL )); then

    MESSAGE="✅ DhabaCart monitoring summary: all systems are healthy.

$REPORT"

    echo "Sending 30-minute healthy summary to Slack..."

    if ! send_slack "$MESSAGE"; then
      echo "ERROR: Slack summary failed"
      exit 1
    fi

    if ! update_state "$NEW_STATE" "$NOW"; then
      echo "ERROR: Could not update monitoring state in ConfigMap"
      exit 1
    fi
  else
    if ! update_state "$NEW_STATE" "$LAST_SUMMARY"; then
      echo "ERROR: Could not update monitoring state in ConfigMap"
      exit 1
    fi
    echo "Healthy. No summary notification is due yet."
  fi

else
  echo "Problems continue. No duplicate failure alert sent."
  if ! update_state "$NEW_STATE" "$LAST_SUMMARY"; then
    echo "ERROR: Could not update monitoring state in ConfigMap"
    exit 1
  fi
fi

echo "Monitoring completed. State: $NEW_STATE"
