#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_command kubectl
assert_tutorial_context

case "${1:-}" in
  argocd)
    log "Argo CD UI: https://localhost:8080 (press Ctrl+C to stop)"
    exec kubectl port-forward --namespace "${ARGOCD_NAMESPACE}" service/argocd-server 8080:443
    ;;
  app)
    log "Example application: http://localhost:8081 (press Ctrl+C to stop)"
    exec kubectl port-forward --namespace "${APP_NAMESPACE}" service/hello-minikube 8081:80
    ;;
  *)
    fail "Choose 'argocd' or 'app'."
    ;;
esac
