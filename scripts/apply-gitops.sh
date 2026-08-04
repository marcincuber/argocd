#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_command git
require_command kubectl
assert_tutorial_context

SOURCE_PATH="${1:-bootstrap}"
[[ "${SOURCE_PATH}" == "bootstrap" || "${SOURCE_PATH}" == "advanced" ]] || \
  fail "Source must be 'bootstrap' or 'advanced'."

REPOSITORY="$(resolve_repo_url)"
TARGET_REVISION="$(resolve_revision)"

[[ "${REPOSITORY}" != *[[:space:]]* ]] || fail "REPO_URL must not contain whitespace."
[[ "${TARGET_REVISION}" != *[[:space:]]* ]] || fail "REVISION must not contain whitespace."

if [[ -n "$(git -C "${TUTORIAL_ROOT}" status --porcelain -- examples bootstrap advanced 2>/dev/null)" ]]; then
  warn "There are uncommitted GitOps files. Argo CD can only read committed and pushed content."
fi

TEMP_DIRECTORY="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIRECTORY}"' EXIT
RENDERED_FILE="${TEMP_DIRECTORY}/${SOURCE_PATH}.yaml"

render_with_git_source "${SOURCE_PATH}" "${REPOSITORY}" "${TARGET_REVISION}" >"${RENDERED_FILE}"

log "Applying '${SOURCE_PATH}' from ${REPOSITORY} at ${TARGET_REVISION}"
kubectl apply -f "${RENDERED_FILE}"

if [[ "${SOURCE_PATH}" == "bootstrap" ]]; then
  kubectl get appproject,application --namespace "${ARGOCD_NAMESPACE}"
else
  kubectl get applicationset --namespace "${ARGOCD_NAMESPACE}"
fi

printf '\nArgo CD reads the remote repository. Push this revision before expecting a successful sync.\n'
