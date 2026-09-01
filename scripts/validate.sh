#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

for command_name in kubectl kubeconform shellcheck; do
  require_command "${command_name}"
done

TEMP_DIRECTORY="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIRECTORY}"' EXIT

"${TUTORIAL_ROOT}/scripts/render.sh" "${TEMP_DIRECTORY}"

log "Validating rendered Kubernetes manifests"
kubernetes_schema_version="${KUBERNETES_VERSION#v}"
kubeconform \
  -strict \
  -summary \
  -ignore-missing-schemas \
  -kubernetes-version "${kubernetes_schema_version}" \
  "${TEMP_DIRECTORY}"/*.yaml

log "Linting Bash scripts"
script_entrypoints=()
for script_file in "${TUTORIAL_ROOT}"/scripts/*.sh; do
  if [[ "$(basename "${script_file}")" != "common.sh" ]]; then
    script_entrypoints+=("${script_file}")
  fi
done
shellcheck -x -P "${TUTORIAL_ROOT}/scripts" "${script_entrypoints[@]}"

markdownlint_cli="${TUTORIAL_ROOT}/node_modules/.bin/markdownlint-cli2"
if [[ -x "${markdownlint_cli}" ]]; then
  log "Linting Markdown"
  "${markdownlint_cli}" \
    "${TUTORIAL_ROOT}/README.md" \
    "${TUTORIAL_ROOT}/docs/**/*.md" \
    "${TUTORIAL_ROOT}/examples/**/*.md"
elif command -v markdownlint-cli2 >/dev/null 2>&1; then
  log "Linting Markdown"
  markdownlint-cli2 \
    "${TUTORIAL_ROOT}/README.md" \
    "${TUTORIAL_ROOT}/docs/**/*.md" \
    "${TUTORIAL_ROOT}/examples/**/*.md"
else
  warn "markdownlint-cli2 is not installed; run 'npm ci'. Markdown lint was skipped."
fi

log "Checking that documentation and manifests match .versions.env"
"${TUTORIAL_ROOT}/scripts/update-docs.sh" --check

printf '\nAll local validation checks passed.\n'
