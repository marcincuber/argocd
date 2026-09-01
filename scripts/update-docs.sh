#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

mode="${1:-update}"
[[ "${mode}" == "update" || "${mode}" == "--check" ]] || \
  fail "Usage: $(basename "$0") [--check]"

outdated_files=0

sync_file() {
  local kind="$1"
  local relative_path="$2"
  local target="${TUTORIAL_ROOT}/${relative_path}"
  local temporary_file

  temporary_file="$(mktemp "${TMPDIR:-/tmp}/argocd-update-docs.XXXXXX")"
  awk \
    -v kind="${kind}" \
    -v kubernetes="${KUBERNETES_VERSION}" \
    -v minikube="${MINIKUBE_VERSION}" \
    -v argocd="${ARGOCD_VERSION}" \
    -v kubeconform="${KUBECONFORM_VERSION}" '
      kind == "readme" {
        if ($0 ~ /^\| Kubernetes \|/) {
          sub(/`v[0-9][0-9.]*`/, "`" kubernetes "`")
        } else if ($0 ~ /^\| Minikube \|/) {
          sub(/`v[0-9][0-9.]*`/, "`" minikube "`")
        } else if ($0 ~ /^\| Argo CD \|/) {
          sub(/`v[0-9][0-9.]*`/, "`" argocd "`")
        } else if ($0 ~ /^\| Kubeconform \|/) {
          sub(/`v[0-9][0-9.]*`/, "`" kubeconform "`")
        } else if ($0 ~ /--kubernetes-version v[0-9]/) {
          sub(/--kubernetes-version v[0-9][0-9.]*/, "--kubernetes-version " kubernetes)
        } else if ($0 ~ /^argocd[[:space:]]+Ready[[:space:]]+control-plane/) {
          sub(/v[0-9][0-9.]*$/, kubernetes)
        }
      }
      kind == "platforms" {
        gsub(/release\/v[0-9][0-9.]*\/bin/, "release/" kubernetes "/bin")
        gsub(/download\/v[0-9][0-9.]*\/argocd/, "download/" argocd "/argocd")
        if ($0 ~ /^\$version = "v[0-9]/) {
          sub(/"v[0-9][0-9.]*"/, "\"" argocd "\"")
        }
      }
      kind == "cluster" {
        sub(/argo-cd\/v[0-9][0-9.]*\/manifests/, "argo-cd/" argocd "/manifests")
      }
      { print }
    ' "${target}" >"${temporary_file}"

  if cmp -s "${target}" "${temporary_file}"; then
    rm -f "${temporary_file}"
    return
  fi

  if [[ "${mode}" == "--check" ]]; then
    printf 'Out of date: %s\n' "${relative_path}" >&2
    outdated_files=$((outdated_files + 1))
    rm -f "${temporary_file}"
    return
  fi

  cp "${temporary_file}" "${target}"
  rm -f "${temporary_file}"
  printf 'Updated: %s\n' "${relative_path}"
}

sync_file readme README.md
sync_file platforms docs/platforms.md
sync_file cluster cluster/kustomization.yaml

if [[ "${mode}" == "--check" ]]; then
  ((outdated_files == 0)) || fail \
    "${outdated_files} file(s) do not match .versions.env. Run: make update-docs"
  printf 'Documentation and manifests match .versions.env.\n'
else
  printf 'Documentation and manifests now match .versions.env.\n'
fi
