# Core concepts

## The reconciliation loop

Argo CD does not execute a one-time deployment pipeline. It repeatedly compares
the desired state rendered from Git with the live Kubernetes state.

```text
Git repository
      |
      v
Argo CD repository server -> rendered Kubernetes objects
                                      |
                                      v
Argo CD application controller -> Kubernetes API -> live resources
             ^                                         |
             +--------------- compare -----------------+
```

With automated sync enabled, a Git difference is applied. With self-healing
enabled, a live-only difference is reverted. With pruning enabled, a live
resource that has been removed from Git is deleted.

## Objects used by this tutorial

| Object | Responsibility |
| --- | --- |
| `AppProject/local-tutorial` | Restricts permitted repositories, destinations, and resource types |
| `Application/hello-minikube` | Connects one Git path to one cluster namespace |
| `ApplicationSet/hello-environments` | Optionally generates dev and staging Applications from a list |
| Kustomize base | Defines reusable Deployment, Service, and content |
| Kustomize overlay | Changes replica count and environment labels without copying the base |

## Sync status and health status

These answer different questions:

- `Synced` means the live resource specifications match the selected Git
  revision.
- `Healthy` means Kubernetes reports that the resulting workload is operating
  correctly.

An Application can be `Synced` but `Degraded` when Git was applied successfully
but a pod cannot start. It can be `OutOfSync` but `Healthy` when the previous
workload still runs while a newer Git revision waits to synchronize.

## Why Git is the source of truth

Manual `kubectl` changes are useful for the self-healing exercise, but they are
not durable configuration. Make intended changes in Git and let Argo CD apply
them. Use `git revert` to roll back so that the reason, author, and exact change
remain auditable.

## Security boundaries in the example

The `local-tutorial` AppProject is narrower than Argo CD's unrestricted
`default` project:

- only the configured repository is accepted;
- only the in-cluster Kubernetes API is accepted;
- only namespaces matching `hello-*` are accepted;
- namespace-scoped resources are allowed for the learning exercises; and
- `Namespace` is the only permitted cluster-scoped kind.

The namespace resource permissions are intentionally broad enough to let users
experiment. A production project should explicitly enumerate permitted kinds,
use separate projects for trust boundaries, disable the administrator account,
configure SSO/RBAC, protect Git branches, and use reviewed pull requests.

The example NGINX image is pinned by multi-platform digest. A tag communicates
the human-readable version while the digest guarantees that every pull resolves
to the same immutable image index.

## Polling and reconciliation timing

Without a webhook, Argo CD periodically checks Git and may take a few minutes to
notice a commit. `argocd app get hello-minikube --refresh` asks for an immediate
comparison; it does not manually sync the Application. Once the new revision is
seen, the automated policy performs the sync.
