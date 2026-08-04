#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_command minikube
[[ -n "${PROFILE}" && "${PROFILE}" != "/" && "${PROFILE}" != "." ]] || fail "Unsafe Minikube profile name."

if [[ "${CONFIRM_DELETE:-}" != "${PROFILE}" ]]; then
  [[ -t 0 ]] || fail "Set CONFIRM_DELETE=${PROFILE} when running non-interactively."
  printf "This deletes the Minikube profile '%s' and all workloads in it.\n" "${PROFILE}"
  read -r -p "Type '${PROFILE}' to continue: " confirmation
  [[ "${confirmation}" == "${PROFILE}" ]] || fail "Confirmation did not match; nothing was deleted."
fi

minikube delete --profile "${PROFILE}"
printf "Deleted Minikube profile '%s'. Git files were not changed.\n" "${PROFILE}"
