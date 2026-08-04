#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_command git
require_command kubectl

log "Checking the '${PROFILE}' Kubernetes context and API server"
assert_tutorial_context
assert_cluster_reachable

if ! kubectl get customresourcedefinition/applications.argoproj.io \
  --request-timeout="${KUBECTL_REQUEST_TIMEOUT}" >/dev/null 2>&1; then
  fail "Argo CD CRDs are not installed in '${PROFILE}'. Run: make install"
fi

SOURCE_PATH="${1:-bootstrap}"
[[ "${SOURCE_PATH}" == "bootstrap" || "${SOURCE_PATH}" == "advanced" ]] || \
  fail "Source must be 'bootstrap' or 'advanced'."

log "Resolving the Git repository and revision"
REPOSITORY="$(resolve_repo_url)"
TARGET_REVISION="$(resolve_revision)"

[[ "${REPOSITORY}" =~ ^[A-Za-z0-9][A-Za-z0-9._~:/@%+-]*$ ]] || fail \
  "REPO_URL contains unsupported characters. Use a standard HTTPS or SSH Git URL without embedded credentials."
[[ "${TARGET_REVISION}" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || fail \
  "REVISION contains unsupported characters. Use a branch, tag, or commit SHA."

if [[ -n "$(git -C "${TUTORIAL_ROOT}" status --porcelain -- examples bootstrap advanced 2>/dev/null)" ]]; then
  warn "There are uncommitted GitOps files. Argo CD can only read committed and pushed content."
fi

if [[ "${SOURCE_PATH}" == "bootstrap" ]]; then
  log "Applying the local bootstrap resources with reconciliation paused"
  kubectl apply \
    --request-timeout="${KUBECTL_REQUEST_TIMEOUT}" \
    -f "${TUTORIAL_ROOT}/bootstrap/hello-minikube.yaml"
  kubectl apply \
    --request-timeout="${KUBECTL_REQUEST_TIMEOUT}" \
    -f "${TUTORIAL_ROOT}/bootstrap/project.yaml"

  log "Configuring ${REPOSITORY} at ${TARGET_REVISION} and enabling reconciliation"
  kubectl patch appproject local-tutorial \
    --namespace "${ARGOCD_NAMESPACE}" \
    --type merge \
    --patch "{\"spec\":{\"sourceRepos\":[\"${REPOSITORY}\"]}}" \
    --request-timeout="${KUBECTL_REQUEST_TIMEOUT}"
  kubectl patch application "${APP_NAME}" \
    --namespace "${ARGOCD_NAMESPACE}" \
    --type merge \
    --patch "{\"metadata\":{\"annotations\":{\"argocd.argoproj.io/skip-reconcile\":null}},\"spec\":{\"source\":{\"repoURL\":\"${REPOSITORY}\",\"targetRevision\":\"${TARGET_REVISION}\"}}}" \
    --request-timeout="${KUBECTL_REQUEST_TIMEOUT}"

  kubectl get appproject,application \
    --namespace "${ARGOCD_NAMESPACE}" \
    --request-timeout="${KUBECTL_REQUEST_TIMEOUT}"
else
  log "Applying the local ApplicationSet"
  kubectl apply \
    --request-timeout="${KUBECTL_REQUEST_TIMEOUT}" \
    -f "${TUTORIAL_ROOT}/advanced/environments.yaml"

  log "Configuring ${REPOSITORY} at ${TARGET_REVISION}"
  kubectl patch applicationset hello-environments \
    --namespace "${ARGOCD_NAMESPACE}" \
    --type merge \
    --patch "{\"spec\":{\"template\":{\"spec\":{\"source\":{\"repoURL\":\"${REPOSITORY}\",\"targetRevision\":\"${TARGET_REVISION}\"}}}}}" \
    --request-timeout="${KUBECTL_REQUEST_TIMEOUT}"

  kubectl get applicationset \
    --namespace "${ARGOCD_NAMESPACE}" \
    --request-timeout="${KUBECTL_REQUEST_TIMEOUT}"
fi

printf '\nArgo CD reads the remote repository. Push this revision before expecting a successful sync.\n'
