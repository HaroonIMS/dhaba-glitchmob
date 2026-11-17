#!/usr/bin/env bash
# Creates one ECR repository per service. Safe to run more than once.
set -euo pipefail

REGION="${AWS_REGION:?export AWS_REGION first}"
TEAM="glitchmob"
SERVICES="web menu-api orders-api kitchen-worker stats-api postgres redis ops-monitor"

LIFECYCLE='{"rules":[{"rulePriority":1,"description":"keep newest 20 images",
  "selection":{"tagStatus":"any","countType":"imageCountMoreThan","countNumber":20},
  "action":{"type":"expire"}}]}'

for svc in $SERVICES; do
  repo="dhaba-${TEAM}/${svc}"
  if aws ecr describe-repositories --region "$REGION" \
       --repository-names "$repo" >/dev/null 2>&1; then
    echo "already exists: $repo"
    continue
  fi
  aws ecr create-repository --region "$REGION" --repository-name "$repo" \
    --image-scanning-configuration scanOnPush=true >/dev/null
  aws ecr put-lifecycle-policy --region "$REGION" --repository-name "$repo" \
    --lifecycle-policy-text "$LIFECYCLE" >/dev/null
  echo "created: $repo"
done
