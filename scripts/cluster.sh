#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_command minikube
require_command kubectl

log "Starting Minikube profile '${PROFILE}' with Kubernetes ${KUBERNETES_VERSION}"
minikube start \
  --profile "${PROFILE}" \
  --driver "${DRIVER:-docker}" \
  --container-runtime "${CONTAINER_RUNTIME:-containerd}" \
  --cpus "${CPUS:-4}" \
  --memory "${MEMORY:-6144}" \
  --kubernetes-version "${KUBERNETES_VERSION}"

assert_tutorial_context
kubectl wait --for=condition=Ready "node/${PROFILE}" --timeout="${TIMEOUT}s"

log "Cluster checkpoint"
kubectl get nodes -o wide
printf '\nExpected: the node above reports Ready and Kubernetes %s.\n' "${KUBERNETES_VERSION}"
