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

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  log "Linting Markdown"
  markdownlint-cli2 \
    "${TUTORIAL_ROOT}/README.md" \
    "${TUTORIAL_ROOT}/docs/**/*.md" \
    "${TUTORIAL_ROOT}/examples/**/*.md"
else
  warn "markdownlint-cli2 is not installed; Markdown lint was skipped. CI runs it on every change."
fi

log "Checking that documented versions match .versions.env"
for version in "${KUBERNETES_VERSION}" "${MINIKUBE_VERSION}" "${ARGOCD_VERSION}" "${KUBECONFORM_VERSION}"; do
  grep -Fq "${version}" "${TUTORIAL_ROOT}/README.md" || fail "README.md does not mention pinned version ${version}."
done
grep -Fq "argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
  "${TUTORIAL_ROOT}/cluster/kustomization.yaml" || fail \
  "cluster/kustomization.yaml does not use ARGOCD_VERSION=${ARGOCD_VERSION}."

printf '\nAll local validation checks passed.\n'
