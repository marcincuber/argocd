# Troubleshooting decision guide

Start with:

```bash
make status
make verify
```

The verification script reports whether failure occurred while comparing Git,
waiting for Kubernetes, or testing HTTP.

| Symptom | Likely cause | First check |
| --- | --- | --- |
| Context safety error | Another cluster is active | `kubectl config current-context` |
| Bootstrap says API server is unreachable | Minikube is stopped or stale | `make start` |
| Minikube start fails | Driver, CPU, or memory issue | `minikube logs --profile argocd --problems` |
| Argo CD pod is `Pending` | Insufficient resources | `kubectl describe pod -n argocd POD` |
| `ImagePullBackOff` | Registry or proxy problem | Pod events and container-engine connectivity |
| Application is `Unknown` | Repository or rendering error | `argocd app get hello-minikube --hard-refresh` |
| Application is `OutOfSync` | New Git revision or live drift | `argocd app diff hello-minikube` |
| Application is `Degraded` | Workload failed after sync | `kubectl get events -n hello-minikube` |
| Project permission error | Repository or namespace not allowed | Inspect `AppProject/local-tutorial` |
| Local URL refuses connection | Port-forward stopped or port occupied | Restart the appropriate `make port-forward-*` command |

## Wrong Kubernetes context

```bash
kubectl config get-contexts
kubectl config use-context argocd
```

The scripts intentionally stop rather than applying to a different cluster.

If the context name is correct but its API endpoint is stale or stopped:

```bash
make start
kubectl get --raw=/readyz --request-timeout=10s
make bootstrap
```

The bootstrap command gives the initial readiness check five seconds and each
subsequent Kubernetes request 30 seconds. These can be changed with
`KUBECTL_READY_TIMEOUT=10s` and `KUBECTL_REQUEST_TIMEOUT=60s` on unusually slow
machines.

Bootstrap has no rendering stage. It applies the local Application with
reconciliation paused, applies the AppProject, patches both with the detected
Git source, and then enables reconciliation. Every Kubernetes operation has an
explicit request timeout.

## Argo CD installation problems

```bash
kubectl get pods --namespace argocd
kubectl get events --namespace argocd --sort-by=.lastTimestamp
kubectl describe pods --namespace argocd
minikube logs --profile argocd --problems
```

If Docker or Podman uses a corporate proxy, configure the engine and Minikube to
reach GitHub, `quay.io`, `registry.k8s.io`, and Docker Hub.

## Git comparison problems

```bash
argocd app get hello-minikube --hard-refresh
argocd app diff hello-minikube
argocd repo list
kubectl describe application hello-minikube --namespace argocd
```

Confirm that:

- the revision was committed and pushed;
- the configured branch exists remotely;
- the Kustomize path exists at that remote revision;
- private repository credentials are registered; and
- the AppProject allows the same repository and destination namespace.

Render the exact path locally:

```bash
kubectl kustomize examples/hello-app/overlays/local
```

## Workload problems

```bash
kubectl get pods --namespace hello-minikube
kubectl get events --namespace hello-minikube --sort-by=.lastTimestamp
kubectl describe deployment hello-minikube --namespace hello-minikube
kubectl logs deployment/hello-minikube --namespace hello-minikube
```

`Synced` plus `Degraded` usually means Git rendered and applied successfully but
the resulting pod or Service is unhealthy.

## Port conflicts

Change only the local side of a mapping:

```bash
kubectl port-forward --namespace argocd service/argocd-server 8443:443
kubectl port-forward --namespace hello-minikube service/hello-minikube 8082:80
```

Use `https://localhost:8443` or `http://localhost:8082` respectively.

## Application stuck deleting

The Application finalizer lets Argo CD delete managed resources before removing
the Application. First restore the Argo CD application controller and retry:

```bash
kubectl rollout status statefulset/argocd-application-controller \
  --namespace argocd
kubectl describe application hello-minikube --namespace argocd
```

Only when the controller cannot be restored and you have inspected or manually
removed the managed resources, remove the finalizer as a last resort:

```bash
kubectl patch application hello-minikube \
  --namespace argocd \
  --type merge \
  --patch '{"metadata":{"finalizers":[]}}'
```

This abandons Argo CD's cascading cleanup and can leave resources behind.

## Complete reset

If the cluster is disposable and diagnosis is no longer useful:

```bash
make clean
make all
```

The clean command requires typing the exact profile name and does not alter Git.
