#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_command kubectl

OUTPUT_DIRECTORY="${1:-}"
if [[ -z "${OUTPUT_DIRECTORY}" ]]; then
  OUTPUT_DIRECTORY="$(mktemp -d)"
  trap 'rm -rf "${OUTPUT_DIRECTORY}"' EXIT
fi
mkdir -p "${OUTPUT_DIRECTORY}"

paths=(
  cluster
  bootstrap
  catalog
  advanced
  examples/hello-app/base
  examples/hello-app/overlays/local
  examples/hello-app/overlays/dev
  examples/hello-app/overlays/staging
  examples/podinfo
  examples/redis
  examples/cronjob
  examples/blue-green
)

for path in "${paths[@]}"; do
  output_name="${path//\//-}.yaml"
  log "Rendering ${path}"
  kubectl kustomize "${TUTORIAL_ROOT}/${path}" >"${OUTPUT_DIRECTORY}/${output_name}"
  document_count="$(grep -c '^kind:' "${OUTPUT_DIRECTORY}/${output_name}" || true)"
  printf '%s objects -> %s\n' "${document_count}" "${OUTPUT_DIRECTORY}/${output_name}"
done

printf '\nAll Kustomizations rendered successfully.\n'
