#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "Checking required commands"
for command_name in git minikube kubectl argocd; do
  require_command "${command_name}"
  printf 'Found %-10s %s\n' "${command_name}" "$(command -v "${command_name}")"
done

case "${DRIVER:-docker}" in
  docker)
    require_command docker
    docker info >/dev/null 2>&1 || fail "Docker is installed but the daemon is not reachable."
    printf 'Docker daemon is reachable.\n'
    ;;
  podman)
    require_command podman
    podman info >/dev/null 2>&1 || fail "Podman is installed but is not ready."
    printf 'Podman is ready.\n'
    ;;
  *)
    warn "Driver '${DRIVER}' was not preflighted; Minikube will validate it."
    ;;
esac

log "Installed versions"
installed_minikube_version="$(minikube version --short 2>/dev/null || true)"
printf 'Minikube: %s\n' "${installed_minikube_version:-unknown}"
if [[ -n "${installed_minikube_version}" && "${installed_minikube_version}" != "${MINIKUBE_VERSION}" ]]; then
  warn "This tutorial was tested with Minikube ${MINIKUBE_VERSION}; installed version is ${installed_minikube_version}."
fi
kubectl version --client
argocd version --client

printf '\nPreflight checks passed.\n'
