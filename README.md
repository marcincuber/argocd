# Run Argo CD locally with Minikube

This tutorial creates a local Kubernetes cluster, installs Argo CD, and
bootstraps an example application that continuously synchronizes from this Git
repository. No cloud account, DNS name, or ingress controller is required.

By the end, the flow is:

```text
Git push -> Argo CD detects the commit -> manifests are rendered -> Minikube is reconciled
```

> This setup is for learning and local development. The non-HA Argo CD install,
> the default administrator account, and port forwarding are not a production
> configuration.

## Version baseline

These instructions were checked on 4 August 2026 and deliberately pin versions
so that the tutorial remains reproducible:

| Component | Version used here | Why |
| --- | --- | --- |
| Kubernetes | `v1.36.2` | Latest stable Kubernetes patch release |
| Minikube | `v1.38.1` or newer | Supports Kubernetes `v1.36.2` |
| Argo CD | `v3.4.6` | Latest stable Argo CD release; install manifest is pinned in `cluster/kustomization.yaml` |

Argo CD's published `3.4` test matrix currently lists Kubernetes `1.32` through
`1.35`, although Minikube supports the newer Kubernetes `1.36.2` used by this
tutorial. If you prefer the latest combination explicitly covered by that test
matrix, replace `v1.36.2` in the start command with `v1.35.6`.

Useful upstream references:

- [Kubernetes patch releases](https://kubernetes.io/releases/patch-releases/)
- [Minikube start command](https://minikube.sigs.k8s.io/docs/commands/start/)
- [Argo CD installation and tested Kubernetes versions](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [Argo CD releases](https://github.com/argoproj/argo-cd/releases)

## Repository layout

```text
.
├── bootstrap/                 # Argo CD Application objects applied once
│   └── hello-minikube.yaml    # Enables auto-sync, prune, and self-heal
├── cluster/                   # Pinned Argo CD installation
└── examples/
    └── hello-app/             # Desired state continuously watched in Git
```

The bootstrap Application uses the public repository
`https://github.com/marcincuber/argocd.git`, branch `main`. If you are working
from a fork, change `spec.source.repoURL` in
`bootstrap/hello-minikube.yaml` before applying it, then commit and push that
change to your fork.

## 1. Install the command-line tools

You need:

- a running Docker-compatible container engine;
- `git`;
- `minikube`;
- `kubectl`; and
- the `argocd` CLI (recommended for login and status commands).

On macOS with Homebrew:

```bash
brew install minikube kubectl argocd
```

Install and start [Docker Desktop](https://docs.docker.com/desktop/) if you do
not already have a container engine. Linux and Windows installation commands
are available in the official guides for
[Minikube](https://minikube.sigs.k8s.io/docs/start/),
[`kubectl`](https://kubernetes.io/docs/tasks/tools/), and
the [Argo CD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/).

Check the tools and Docker before continuing:

```bash
docker info
minikube version
kubectl version --client
argocd version --client
```

You do not need a separate `kustomize` installation: the commands below use
the Kustomize support built into `kubectl`.

## 2. Clone the repository

Skip this step if you are already in this repository.

```bash
git clone https://github.com/marcincuber/argocd.git
cd argocd
```

Run all remaining commands from the repository root.

## 3. Start Kubernetes with Minikube

Create a dedicated profile named `argocd` using the latest stable Kubernetes
release:

```bash
minikube start \
  --profile argocd \
  --driver docker \
  --container-runtime containerd \
  --cpus 4 \
  --memory 6144 \
  --kubernetes-version v1.36.2
```

Minikube changes the active `kubectl` context to `argocd`. Verify the context,
cluster version, and node health before installing anything:

```bash
kubectl config current-context
kubectl version
kubectl get nodes -o wide
minikube status --profile argocd
```

The current context should be `argocd`, and the node should report `Ready`. If
Docker has less than 6 GiB available, increase its memory allocation or lower
`--memory` to `4096`; startup and image pulls will be slower with 4 GiB.

## 4. Install Argo CD

The `cluster` Kustomization creates the `argocd` namespace and installs the
pinned non-HA Argo CD release:

```bash
kubectl apply --server-side --force-conflicts -k cluster
```

Wait until every Argo CD pod is ready. The first pull can take a few minutes:

```bash
kubectl wait \
  --namespace argocd \
  --for=condition=Ready pod \
  --all \
  --timeout=300s

kubectl get pods --namespace argocd
```

All pods should show `Running` and all containers should be ready. A pod that
briefly shows `Init` or `ContainerCreating` during the initial image pull is
normal.

## 5. Open Argo CD and log in

Keep this port-forward running in its own terminal:

```bash
kubectl port-forward --namespace argocd service/argocd-server 8080:443
```

The UI is now at [https://localhost:8080](https://localhost:8080). The local
certificate is self-signed, so the browser will display a certificate warning.

In another terminal, print the generated password and log in as `admin`:

```bash
argocd admin initial-password --namespace argocd

argocd login localhost:8080 \
  --username admin \
  --password "$(argocd admin initial-password --namespace argocd)" \
  --insecure
```

For a disposable local cluster it is fine to keep the generated password. On a
long-lived installation, change it with `argocd account update-password` and
delete the initial secret afterward.

## 6. Bootstrap the automatically synchronized application

Apply the Argo CD `Application` object:

```bash
kubectl apply -k bootstrap
```

That single object tells Argo CD to:

- watch `examples/hello-app` on the `main` branch;
- create the `hello-minikube` namespace;
- deploy the ConfigMap, Deployment, and Service;
- automatically apply new Git commits;
- repair manual changes in the cluster (`selfHeal: true`); and
- delete resources removed from Git (`prune: true`).

Watch the first synchronization and wait for it to become healthy:

```bash
argocd app get hello-minikube
argocd app wait hello-minikube --sync --health --timeout 300

kubectl get all --namespace hello-minikube
```

If the Application reports `ComparisonError`, confirm that the repository URL,
branch, and path in `bootstrap/hello-minikube.yaml` exist in the remote Git
repository. Argo CD reads Git, not uncommitted files on your laptop.

## 7. Open the example application

Keep a second port-forward running:

```bash
kubectl port-forward \
  --namespace hello-minikube \
  service/hello-minikube 8081:80
```

Open [http://localhost:8081](http://localhost:8081), or test it from another
terminal:

```bash
curl http://localhost:8081
```

You should see **Hello from Argo CD!**.

## 8. Prove that automatic sync works

Edit the message in `examples/hello-app/configmap.yaml` or change `replicas: 2`
in `examples/hello-app/deployment.yaml`. Render the manifests locally, then
commit and push:

```bash
kubectl kustomize examples/hello-app
git add examples/hello-app
git commit -m "Update the hello application"
git push origin main
```

Argo CD polls Git periodically, so detection can take up to about three
minutes. Force an immediate Git refresh without manually syncing the app:

```bash
argocd app get hello-minikube --refresh
argocd app wait hello-minikube --sync --health --timeout 300
```

Refresh [http://localhost:8081](http://localhost:8081), or inspect the deployed
state:

```bash
kubectl get deployment hello-minikube \
  --namespace hello-minikube \
  -o jsonpath='{.spec.replicas}{" replicas\n"}'
```

### Prove self-healing

Create drift by changing the live Deployment without changing Git:

```bash
kubectl scale deployment hello-minikube \
  --namespace hello-minikube \
  --replicas 1

kubectl get deployment hello-minikube \
  --namespace hello-minikube \
  --watch
```

Argo CD will restore the replica count declared in Git. Press `Ctrl+C` to stop
watching.

## Everyday commands

```bash
# Show Applications using kubectl
kubectl get applications --namespace argocd

# Show detailed sync and health information
argocd app get hello-minikube

# Show resources managed by the Application
argocd app resources hello-minikube

# Inspect controller logs
kubectl logs --namespace argocd \
  statefulset/argocd-application-controller \
  --tail=100

# Stop the cluster without deleting it
minikube stop --profile argocd

# Start the same cluster again
minikube start --profile argocd
```

## Troubleshooting

### The wrong cluster is active

Always check before applying manifests:

```bash
kubectl config current-context
kubectl config use-context argocd
```

### Argo CD pods do not become ready

```bash
kubectl get pods --namespace argocd
kubectl describe pods --namespace argocd
minikube logs --profile argocd --problems
```

`ImagePullBackOff` usually means the container engine cannot reach an image
registry. `Pending` often means Docker needs more memory or CPU.

### The Application is `OutOfSync` or has a comparison error

```bash
argocd app get hello-minikube --hard-refresh
argocd app diff hello-minikube
kubectl get application hello-minikube \
  --namespace argocd \
  -o yaml
```

Check that your changes were committed and pushed to the branch configured in
the Application. For a private fork, add repository credentials in Argo CD or
make the repository accessible to the local Argo CD instance.

### Port 8080 or 8081 is already in use

Change only the local side of the mapping, for example `8443:443` for Argo CD
or `8082:80` for the example. Then use the matching local URL.

## Clean up

Delete only the example and let its finalizer remove the managed resources:

```bash
kubectl delete -k bootstrap
```

Or delete the entire disposable Minikube profile, including Argo CD and the
example:

```bash
minikube delete --profile argocd
```

The Git files remain unchanged, so you can recreate the complete environment by
starting again at step 3.
