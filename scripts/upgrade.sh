#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_command kubectl
assert_tutorial_context

log "Previewing changes for Argo CD ${ARGOCD_VERSION}"
set +e
kubectl diff -k "${TUTORIAL_ROOT}/cluster"
diff_status=$?
set -e

if ((diff_status > 1)); then
  fail "kubectl diff failed. No changes were applied."
elif ((diff_status == 0)); then
  printf 'The cluster already matches the pinned installer.\n'
else
  printf 'Differences found.\n'
fi

if [[ "${CONFIRM_UPGRADE:-}" != "true" ]]; then
  [[ -t 0 ]] || fail "Set CONFIRM_UPGRADE=true when running non-interactively."
  read -r -p "Apply Argo CD ${ARGOCD_VERSION}? [y/N] " confirmation
  [[ "${confirmation}" =~ ^[Yy]$ ]] || fail "Upgrade cancelled; no changes were applied."
fi

"${TUTORIAL_ROOT}/scripts/install.sh"

log "Installed Argo CD image"
kubectl get deployment argocd-server \
  --namespace "${ARGOCD_NAMESPACE}" \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
