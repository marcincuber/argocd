#!/usr/bin/env bash

set -Eeuo pipefail

TUTORIAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${TUTORIAL_ROOT}/.versions.env" ]]; then
  requested_kubernetes_version="${KUBERNETES_VERSION:-}"
  requested_minikube_version="${MINIKUBE_VERSION:-}"
  requested_argocd_version="${ARGOCD_VERSION:-}"
  requested_kubeconform_version="${KUBECONFORM_VERSION:-}"
  set -a
  # shellcheck source=../.versions.env
  source "${TUTORIAL_ROOT}/.versions.env"
  set +a
  KUBERNETES_VERSION="${requested_kubernetes_version:-${KUBERNETES_VERSION}}"
  MINIKUBE_VERSION="${requested_minikube_version:-${MINIKUBE_VERSION}}"
  ARGOCD_VERSION="${requested_argocd_version:-${ARGOCD_VERSION}}"
  KUBECONFORM_VERSION="${requested_kubeconform_version:-${KUBECONFORM_VERSION}}"
fi

PROFILE="${PROFILE:-argocd}"
TIMEOUT="${TIMEOUT:-300}"
ARGOCD_NAMESPACE="argocd"
APP_NAME="hello-minikube"
APP_NAMESPACE="hello-minikube"
DEFAULT_REPO_URL="https://github.com/marcincuber/argocd.git"

log() {
  printf '\n==> %s\n' "$*"
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' was not found in PATH."
}

assert_tutorial_context() {
  local current_context
  current_context="$(kubectl config current-context 2>/dev/null || true)"
  [[ "${current_context}" == "${PROFILE}" ]] || fail \
    "kubectl context is '${current_context:-unset}', expected '${PROFILE}'. Run: kubectl config use-context ${PROFILE}"
}

normalise_repo_url() {
  local url="$1"

  if [[ "${url}" =~ ^git@([^:]+):(.+)$ ]]; then
    printf 'https://%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  elif [[ "${url}" =~ ^ssh://git@([^/]+)/(.+)$ ]]; then
    printf 'https://%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  else
    printf '%s\n' "${url}"
  fi
}

resolve_repo_url() {
  local detected_url

  if [[ -n "${REPO_URL:-}" ]]; then
    printf '%s\n' "${REPO_URL}"
    return
  else
    detected_url="$(git -C "${TUTORIAL_ROOT}" remote get-url origin 2>/dev/null || true)"
  fi

  [[ -n "${detected_url}" ]] || fail \
    "Could not determine a Git repository URL. Set REPO_URL=https://example.com/owner/repository.git."

  normalise_repo_url "${detected_url}"
}

resolve_revision() {
  local detected_revision

  if [[ -n "${REVISION:-}" ]]; then
    detected_revision="${REVISION}"
  else
    detected_revision="$(git -C "${TUTORIAL_ROOT}" branch --show-current 2>/dev/null || true)"
  fi

  printf '%s\n' "${detected_revision:-main}"
}

render_with_git_source() {
  local source_path="$1"
  local repo_url="$2"
  local revision="$3"

  kubectl kustomize "${TUTORIAL_ROOT}/${source_path}" | awk \
    -v old_repo="${DEFAULT_REPO_URL}" \
    -v new_repo="${repo_url}" \
    -v revision="${revision}" '
      function replace_all(value, old, replacement, position) {
        while ((position = index(value, old)) > 0) {
          value = substr(value, 1, position - 1) replacement substr(value, position + length(old))
        }
        return value
      }
      {
        line = replace_all($0, old_repo, new_repo)
        if (line ~ /^[[:space:]]*targetRevision:/) {
          sub(/targetRevision:.*/, "targetRevision: " revision, line)
        }
        print line
      }
    '
}
