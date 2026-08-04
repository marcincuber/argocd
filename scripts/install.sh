#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_command kubectl
assert_tutorial_context

log "Installing Argo CD ${ARGOCD_VERSION}"
kubectl apply --server-side --force-conflicts -k "${TUTORIAL_ROOT}/cluster"

kubectl wait \
  --for=condition=Established \
  customresourcedefinition/applications.argoproj.io \
  --timeout="${TIMEOUT}s"
kubectl rollout status deployment --all \
  --namespace "${ARGOCD_NAMESPACE}" \
  --timeout="${TIMEOUT}s"
kubectl rollout status statefulset --all \
  --namespace "${ARGOCD_NAMESPACE}" \
  --timeout="${TIMEOUT}s"

log "Argo CD checkpoint"
kubectl get pods --namespace "${ARGOCD_NAMESPACE}"
printf '\nExpected: every pod above reports Running and all containers are ready.\n'
