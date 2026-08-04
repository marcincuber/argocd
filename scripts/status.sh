#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_command minikube
require_command kubectl
assert_tutorial_context

log "Minikube"
minikube status --profile "${PROFILE}"

log "Argo CD"
kubectl get pods --namespace "${ARGOCD_NAMESPACE}"
kubectl get appprojects,applications --namespace "${ARGOCD_NAMESPACE}"

log "Example application"
kubectl get all --namespace "${APP_NAMESPACE}"
