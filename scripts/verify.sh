#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_command kubectl
assert_tutorial_context

log "Waiting for Application '${APP_NAME}' to become Synced and Healthy"
deadline=$((SECONDS + TIMEOUT))

while ((SECONDS < deadline)); do
  sync_status="$(kubectl get application "${APP_NAME}" --namespace "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  health_status="$(kubectl get application "${APP_NAME}" --namespace "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
  printf 'sync=%-12s health=%s\n' "${sync_status:-Pending}" "${health_status:-Pending}"

  if [[ "${sync_status}" == "Synced" && "${health_status}" == "Healthy" ]]; then
    break
  fi
  sleep 5
done

if [[ "${sync_status:-}" != "Synced" || "${health_status:-}" != "Healthy" ]]; then
  kubectl describe application "${APP_NAME}" --namespace "${ARGOCD_NAMESPACE}" || true
  fail "Application did not become Synced and Healthy within ${TIMEOUT} seconds."
fi

kubectl rollout status "deployment/${APP_NAME}" \
  --namespace "${APP_NAMESPACE}" \
  --timeout="${TIMEOUT}s"

log "Running an in-cluster HTTP smoke test"
response="$(kubectl exec \
  --namespace "${APP_NAMESPACE}" \
  "deployment/${APP_NAME}" \
  -- wget -qO- "http://${APP_NAME}")"

grep -q 'Hello from Argo CD' <<<"${response}" || fail "The HTTP response did not contain the expected text."

kubectl get application "${APP_NAME}" --namespace "${ARGOCD_NAMESPACE}"
kubectl get all --namespace "${APP_NAMESPACE}"
printf '\nVerification passed: Git is synced, workloads are healthy, and HTTP responded correctly.\n'
