# Example application catalog

The main tutorial deploys `hello-minikube`. Run `make examples` after
`make bootstrap` to create four additional Applications from the
`tutorial-examples` ApplicationSet.

| Application | Namespace | Workload pattern | What to explore |
| --- | --- | --- | --- |
| `hello-minikube` | `hello-minikube` | Kustomize overlays | Sync, self-healing, pruning, rollback |
| `example-podinfo` | `tutorial-podinfo` | Stateless microservice | Probes, replicas, Service routing |
| `example-redis` | `tutorial-redis` | StatefulSet | Stable identity and persistent storage |
| `example-cronjob` | `tutorial-cronjob` | CronJob | Scheduled and short-lived workloads |
| `example-blue-green` | `tutorial-blue-green` | Parallel releases | Git-controlled traffic switching |

## Deploy the catalog

Commit and push the example and catalog files first because Argo CD reads the
remote Git repository. Then run:

```bash
make bootstrap
make examples
kubectl get applicationsets,applications --namespace argocd
```

Wait for the four generated Applications:

```bash
for application in podinfo redis cronjob blue-green; do
  argocd app wait "example-${application}" --sync --health --timeout 300
done
```

## Podinfo: probes and service routing

Forward the Service and inspect the pod metadata exposed by Podinfo:

```bash
kubectl port-forward service/podinfo 8082:80 --namespace tutorial-podinfo
```

Open [http://localhost:8082](http://localhost:8082). In another terminal,
scale the Deployment in Git, push the change, and watch Argo CD roll it out.

## Redis: persistent state

Write and read a value, delete the pod, and verify that the replacement pod can
still read it from the persistent volume:

```bash
kubectl exec statefulset/redis --namespace tutorial-redis -- \
  redis-cli SET tutorial argocd
kubectl delete pod redis-0 --namespace tutorial-redis
kubectl rollout status statefulset/redis --namespace tutorial-redis
kubectl exec statefulset/redis --namespace tutorial-redis -- \
  redis-cli GET tutorial
```

## CronJob: scheduled reconciliation

The heartbeat runs every five minutes. Trigger one execution immediately and
inspect its output:

```bash
kubectl create job manual-heartbeat \
  --from=cronjob/gitops-heartbeat \
  --namespace tutorial-cronjob
kubectl logs job/manual-heartbeat --namespace tutorial-cronjob
kubectl delete job manual-heartbeat --namespace tutorial-cronjob
```

The manual Job is intentionally deleted because it is not part of Git and the
AppProject reports unmanaged namespace resources as orphans.

## Blue/green: switch traffic through Git

The blue and green Deployments run together, while the Service selects blue:

```bash
kubectl port-forward service/color-demo 8083:80 \
  --namespace tutorial-blue-green
curl http://localhost:8083
```

Change `tutorial.argocd.io/track` in `blue-green/service.yaml` from `blue` to
`green`, commit, and push. Argo CD changes the Service selector without
recreating either Deployment, and the same request returns the green page.

## Remove the optional examples

Delete the ApplicationSet through Kustomize. Its generated Applications use
the Argo CD resources finalizer, so their managed resources are pruned:

```bash
kubectl delete -k catalog
```

The main `hello-minikube` Application is independent and remains available.
