# Run Argo CD locally with Minikube

Create a local Kubernetes cluster, install Argo CD, and deploy an application
that continuously reconciles itself from Git. The tutorial includes a fast
automated path and a step-by-step path that explains what each component does.

```text
Git push -> Argo CD detects the revision -> Kustomize renders it -> Minikube is reconciled
```

Allow about 15–25 minutes for the first run, mostly for downloading images. No
cloud account, DNS name, or ingress controller is required.

> This is a learning environment. The non-HA installation, administrator login,
> broad namespace permissions inside the tutorial project, and local port
> forwarding are not a production configuration.

## Tested version baseline

The central pins live in [`.versions.env`](.versions.env). After changing them,
run `make update-docs` to synchronize the examples below.

| Component | Tested version | Purpose |
| --- | --- | --- |
| Kubernetes | `v1.37.0` | Local cluster API and workloads |
| Minikube | `v1.38.1` | Local cluster lifecycle |
| Argo CD | `v3.5.2` | GitOps controller, API, CLI, and UI |
| Kubeconform | `v0.8.0` | Optional local and CI schema validation |

Before changing the baseline, confirm that Argo CD supports the selected
Kubernetes version in its published compatibility matrix.

## What the repository contains

```text
.
├── cluster/                    # Pinned Argo CD installer
├── bootstrap/                  # Restricted AppProject and main Application
├── catalog/                    # Four optional Applications generated as a set
├── advanced/                   # Optional dev/staging ApplicationSet
├── examples/hello-app/
│   ├── base/                   # Deployment, Service, and generated ConfigMap
│   └── overlays/               # local, dev, and staging Kustomize overlays
├── examples/{podinfo,redis,cronjob,blue-green}/
│                               # Optional workload-pattern examples
├── scripts/                    # Safe setup, verification, and maintenance tools
├── docs/                       # Concepts and optional learning tracks
└── Makefile                    # Short user-facing commands
```

The main Application enables automatic sync, pruning, self-healing, namespace
creation, and retry backoff. Its `AppProject` limits it to this repository and
namespaces matching `hello-*` or `tutorial-*`.

## 1. Install prerequisites

You need Git, Make, `kubectl`, Minikube, the Argo CD CLI, and either Docker or
Podman. On macOS:

```bash
brew install git make kubectl minikube argocd
```

Install and start [Docker Desktop](https://docs.docker.com/desktop/) if you do
not already have a container engine. See [platform setup](docs/platforms.md)
for Linux, Windows/WSL, Apple Silicon, and Podman instructions.

## 2. Fork and clone

Fork this repository so that you can push GitOps changes, then clone your fork:

```bash
git clone https://github.com/YOUR-USER/argocd.git
cd argocd
```

The automation derives the Argo CD source URL and branch from your `origin`
remote. You can override them at any time:

```bash
make bootstrap \
  REPO_URL=https://github.com/YOUR-USER/argocd.git \
  REVISION=main
```

Argo CD reads the remote repository—not uncommitted files on your computer.

## Fast path

Run the preflight check, create the cluster, install Argo CD, bootstrap the
application, and execute the smoke test:

```bash
make doctor
make all
```

`make all` stops at the first failure and prints diagnostics. If it succeeds,
the Application is `Synced`, the workload is `Healthy`, two replicas are ready,
and an in-cluster HTTP request has returned the expected page.

Open the application in a separate terminal:

```bash
make port-forward-app
```

Visit [http://localhost:8081](http://localhost:8081).

The sections below perform the same workflow one checkpoint at a time.

## 3. Run the preflight check

```bash
make doctor
```

Expected checkpoint: every command is found and the selected container engine
is reachable. The default driver is Docker; use `DRIVER=podman` for Podman.

## 4. Create the Minikube cluster

```bash
make cluster
```

The defaults are equivalent to:

```bash
minikube start \
  --profile argocd \
  --driver docker \
  --container-runtime containerd \
  --cpus 4 \
  --memory 6144 \
  --kubernetes-version v1.37.0
```

Expected checkpoint:

```text
NAME     STATUS   ROLES           VERSION
argocd   Ready    control-plane   v1.37.0
```

All scripts refuse to modify Kubernetes if the active context is not the
configured Minikube profile. Override resources when necessary:

```bash
make cluster CPUS=3 MEMORY=4096 DRIVER=podman
```

## 5. Install Argo CD

```bash
make install
```

This applies `cluster/` with server-side apply, waits for the CRDs, and checks
all Argo CD Deployment and StatefulSet rollouts. Expected checkpoint: every pod
in the `argocd` namespace is `Running` and ready.

Inspect without changing the cluster:

```bash
kubectl get pods --namespace argocd
kubectl get crd applications.argoproj.io
```

## 6. Open Argo CD and log in

Keep the UI port-forward running:

```bash
make port-forward-argocd
```

Visit [https://localhost:8080](https://localhost:8080). A certificate warning is
expected because this disposable environment uses a self-signed certificate.

In another terminal:

```bash
argocd admin initial-password --namespace argocd

argocd login localhost:8080 \
  --username admin \
  --password "$(argocd admin initial-password --namespace argocd | head -1)" \
  --insecure
```

## 7. Bootstrap GitOps

Ensure the current revision is committed and pushed, then run:

```bash
make bootstrap
make verify
```

The bootstrap command applies the local resources with reconciliation paused,
sets your detected Git remote and branch, and then enables reconciliation. It
does not generate or render an intermediate manifest. It creates:

- `local-tutorial`, an AppProject restricted to the repository and the tutorial
  namespaces;
- `hello-minikube`, an Application watching `overlays/local`; and
- the `hello-minikube` namespace and application resources through Argo CD.

Expected checkpoint:

```text
NAME             SYNC STATUS   HEALTH STATUS
hello-minikube   Synced        Healthy
```

Use an explicit source when working from a different remote or branch:

```bash
make bootstrap REPO_URL=https://github.com/USER/REPO.git REVISION=feature/tutorial
```

Private repositories require credentials before bootstrapping. Follow
[the private repository guide](docs/private-repositories.md).

## 8. Open and inspect the example

```bash
make port-forward-app
```

Visit [http://localhost:8081](http://localhost:8081), or run:

```bash
curl http://localhost:8081
make status
```

## Optional: deploy all five examples

The main application is example one. Deploy four additional Applications with
one ApplicationSet:

```bash
make examples
kubectl get applicationsets,applications --namespace argocd
```

The catalog adds a health-aware Podinfo microservice, persistent Redis
StatefulSet, scheduled heartbeat CronJob, and blue/green web deployment. See the
[example catalog](examples/README.md) for verification exercises and cleanup.

## 9. GitOps exercises

### Exercise A: automatic sync and a rolling content update

Edit `examples/hello-app/base/content/index.html`, then render, commit, and push:

```bash
kubectl kustomize examples/hello-app/overlays/local
git add examples/hello-app/base/content/index.html
git commit -m "Change the tutorial page"
git push origin HEAD
```

Kustomize gives the generated ConfigMap a content hash. The changed name updates
the Deployment pod template, producing a real rolling update instead of waiting
for a mounted ConfigMap cache refresh.

```bash
argocd app get hello-minikube --refresh
kubectl rollout status deployment/hello-minikube \
  --namespace hello-minikube
kubectl get configmaps --namespace hello-minikube
```

### Exercise B: self-healing

Create live drift without changing Git:

```bash
kubectl scale deployment hello-minikube \
  --namespace hello-minikube \
  --replicas 1

kubectl get deployment hello-minikube \
  --namespace hello-minikube \
  --watch
```

Argo CD restores the two replicas declared by `overlays/local`. Press `Ctrl+C`
after the replica count returns to two.

### Exercise C: pruning

Delete `base/prune-demo.yaml` and remove it from `base/kustomization.yaml`, then
commit and push:

```bash
git add examples/hello-app/base
git commit -m "Remove the prune demonstration resource"
git push origin HEAD
argocd app get hello-minikube --refresh
```

Observe Argo CD remove the ConfigMap because `prune: true`:

```bash
kubectl get configmap prune-demo --namespace hello-minikube
```

Expected result: `NotFound`.

### Exercise D: Git rollback

Restore the previous desired state with Git rather than editing the cluster:

```bash
git revert HEAD
git push origin HEAD
argocd app get hello-minikube --refresh
make verify
```

Argo CD recreates `prune-demo`. This is the auditable GitOps rollback pattern.

## Optional learning tracks

- [Core concepts and security boundaries](docs/concepts.md)
- [Kustomize overlays, ApplicationSet, and webhooks](docs/advanced.md)
- [Private repository authentication](docs/private-repositories.md)
- [Safe Argo CD upgrades and rollback](docs/upgrading.md)
- [Troubleshooting decision guide](docs/troubleshooting.md)
- [Platform-specific installation](docs/platforms.md)

## Everyday commands

```bash
make help                 # List commands and configurable variables
make status               # Show cluster, controllers, and application
make verify               # Repeat the complete smoke test
make examples             # Deploy all five tutorial applications
make render               # Render every Kustomization locally
make validate             # Schema-check manifests and lint scripts/docs
make check-versions       # Compare pins with upstream stable releases
make update-docs          # Synchronize docs/manifests with version pins
make stop                 # Preserve but stop the cluster
make start                # Restart the same profile
make upgrade              # Preview and apply a pinned Argo CD upgrade
make clean                # Confirm and delete only this Minikube profile
```

For complete local validation on macOS, install the development tools once:

```bash
brew install kubeconform shellcheck node
npm ci
make validate
```

## Clean up

Delete only the example and wait for its finalizer to prune managed resources
before deleting the project:

```bash
kubectl delete -k catalog --ignore-not-found
kubectl delete application hello-minikube --namespace argocd
kubectl wait --for=delete application/hello-minikube \
  --namespace argocd \
  --timeout=300s
kubectl delete appproject local-tutorial --namespace argocd
```

Delete the entire disposable cluster with an interactive profile-name check:

```bash
make clean
```

Git files remain unchanged, so the environment can be recreated with
`make all`.

## Maintenance and validation

GitHub Actions renders and schema-validates every manifest, lints Bash and
Markdown, and checks documentation links. Dependabot groups weekly updates for
GitHub Actions, npm development dependencies, and container images referenced
by the Kubernetes manifests. The central tool and Argo CD pins are a tested
baseline: audit them with `make check-versions` and review updates together as
described in the [upgrade guide](docs/upgrading.md). After changing a pin, run
`make update-docs` to synchronize every version-dependent example.

Primary references:

- [Kubernetes releases](https://kubernetes.io/releases/patch-releases/)
- [Minikube documentation](https://minikube.sigs.k8s.io/docs/)
- [Argo CD installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [Argo CD automated sync](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- [Kustomize](https://kubectl.docs.kubernetes.io/references/kustomize/)
