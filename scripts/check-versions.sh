#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_command curl
require_command jq

github_latest() {
  local repository="$1"
  local curl_args=(-fsSL -H "Accept: application/vnd.github+json")

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  curl "${curl_args[@]}" "https://api.github.com/repos/${repository}/releases/latest" | jq -r '.tag_name'
}

failures=0

check_version() {
  local component="$1"
  local pinned="$2"
  local latest="$3"

  if [[ "${pinned}" == "${latest}" ]]; then
    printf '%-14s current (%s)\n' "${component}" "${pinned}"
  else
    printf '%-14s pinned=%s latest=%s\n' "${component}" "${pinned}" "${latest}"
    failures=$((failures + 1))
  fi
}

log "Comparing version pins with official upstream releases"
check_version "Kubernetes" "${KUBERNETES_VERSION}" "$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
check_version "Minikube" "${MINIKUBE_VERSION}" "$(github_latest kubernetes/minikube)"
check_version "Argo CD" "${ARGOCD_VERSION}" "$(github_latest argoproj/argo-cd)"
check_version "Kubeconform" "${KUBECONFORM_VERSION}" "$(github_latest yannh/kubeconform)"

if ((failures > 0)); then
  fail "${failures} pinned version(s) are behind upstream. Renovate should propose updates."
fi

printf '\nAll tracked tools use the latest stable releases.\n'
