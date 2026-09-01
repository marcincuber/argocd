SHELL := /usr/bin/env bash
.NOTPARALLEL:

include .versions.env

PROFILE ?= argocd
DRIVER ?= docker
CONTAINER_RUNTIME ?= containerd
CPUS ?= 4
MEMORY ?= 6144
REPO_URL ?=
REVISION ?=
TIMEOUT ?= 300
KUBECTL_REQUEST_TIMEOUT ?= 30s
KUBECTL_READY_TIMEOUT ?= 5s

export PROFILE DRIVER CONTAINER_RUNTIME CPUS MEMORY REPO_URL REVISION TIMEOUT
export KUBECTL_REQUEST_TIMEOUT
export KUBECTL_READY_TIMEOUT
export KUBERNETES_VERSION MINIKUBE_VERSION ARGOCD_VERSION KUBECONFORM_VERSION

.DEFAULT_GOAL := help

.PHONY: help doctor all cluster install bootstrap examples advanced verify status \
	port-forward-argocd port-forward-app render validate check-versions \
	update-docs upgrade stop start clean

help: ## Show the available commands.
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target> [VARIABLE=value]\n\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

doctor: ## Check that the required local tools and container engine work.
	@./scripts/doctor.sh

all: cluster install bootstrap verify ## Create and verify the complete tutorial environment.

cluster: doctor ## Create or update the dedicated Minikube profile.
	@./scripts/cluster.sh

install: ## Install the pinned Argo CD release in the active tutorial cluster.
	@./scripts/install.sh

bootstrap: ## Apply the AppProject and local example using your Git remote.
	@./scripts/apply-gitops.sh bootstrap

examples: ## Deploy the four optional examples (five applications in total).
	@./scripts/apply-gitops.sh catalog

advanced: ## Deploy the optional dev/staging ApplicationSet example.
	@./scripts/apply-gitops.sh advanced

verify: ## Wait for Argo CD and run an in-cluster HTTP smoke test.
	@./scripts/verify.sh

status: ## Show cluster, Argo CD, and example application status.
	@./scripts/status.sh

port-forward-argocd: ## Forward the Argo CD UI to https://localhost:8080.
	@./scripts/port-forward.sh argocd

port-forward-app: ## Forward the example application to http://localhost:8081.
	@./scripts/port-forward.sh app

render: ## Render every Kustomization without applying it.
	@./scripts/render.sh

validate: ## Render, schema-check, lint scripts, and check documented versions.
	@./scripts/validate.sh

check-versions: ## Compare the pinned tools with current upstream releases.
	@./scripts/check-versions.sh

update-docs: ## Synchronize documentation and manifests with .versions.env.
	@./scripts/update-docs.sh

upgrade: ## Diff, apply, and verify the pinned Argo CD installation.
	@./scripts/upgrade.sh

stop: ## Stop the tutorial profile without deleting it.
	@minikube stop --profile "$(PROFILE)"

start: ## Restart an existing tutorial profile.
	@minikube start --profile "$(PROFILE)"

clean: ## Delete the tutorial Minikube profile after interactive confirmation.
	@./scripts/clean.sh
