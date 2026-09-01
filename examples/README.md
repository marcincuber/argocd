# Example application catalog

The tutorial has a core application and two optional learning tracks. Start
with the simple track, then add the complex track when you want to explore
state, release strategies, and applications made from several components.

| Track | Application | Namespace | What to explore |
| --- | --- | --- | --- |
| Core | `hello-minikube` | `hello-minikube` | Sync, self-healing, pruning, rollback |
| Simple | `example-configmap` | `tutorial-configmap` | Configuration drift without a workload |
| Simple | `example-web-server` | `tutorial-web-server` | Deployment, Service, generated content |
| Simple | `example-podinfo` | `tutorial-podinfo` | Probes, replicas, Service routing |
| Simple | `example-cronjob` | `tutorial-cronjob` | Scheduled and short-lived workloads |
| Complex | `example-redis` | `tutorial-redis` | Stable identity and persistent storage |
| Complex | `example-blue-green` | `tutorial-blue-green` | Git-controlled traffic switching |
| Complex | `example-multi-tier` | `tutorial-multi-tier` | Frontend-to-backend service discovery |
| Complex | `example-rolling-update` | `tutorial-rolling-update` | Availability during a rollout |

## Deploy a track

Commit and push the example and catalog files first because Argo CD reads the
remote Git repository. Bootstrap the core tutorial, then choose a track:

```bash
make bootstrap
make examples-simple
make examples-complex
```

Use `make examples` to deploy both tracks at once. The track label makes the
generated Applications easy to filter:

```bash
kubectl get applications --namespace argocd \
  --label tutorial.argocd.io/difficulty=simple
kubectl get applications --namespace argocd \
  --label tutorial.argocd.io/difficulty=complex
```

Wait for every optional Application:

```bash
for application in configmap web-server podinfo cronjob \
  redis blue-green multi-tier rolling-update; do
  argocd app wait "example-${application}" --sync --health --timeout 300
done
```

## Simple exercises

### ConfigMap: configuration drift

Inspect the value managed from Git, change it directly, and watch self-healing
restore the declared value:

```bash
kubectl get configmap tutorial-config --namespace tutorial-configmap \
  --output jsonpath='{.data.greeting}{"\n"}'
kubectl patch configmap tutorial-config --namespace tutorial-configmap \
  --type merge --patch '{"data":{"greeting":"changed outside Git"}}'
argocd app wait example-configmap --sync --timeout 300
```

### Web server: a minimal workload

```bash
kubectl port-forward service/web-server 8082:80 \
  --namespace tutorial-web-server
```

Open [http://localhost:8082](http://localhost:8082). Change the generated
`index.html` literal in `web-server/kustomization.yaml`, commit, and push to
observe a rolling content update.

### Podinfo: probes and service routing

```bash
kubectl port-forward service/podinfo 8083:80 --namespace tutorial-podinfo
```

Open [http://localhost:8083](http://localhost:8083). Scale the Deployment in
Git, push the change, and watch Argo CD roll it out.

### CronJob: scheduled reconciliation

The heartbeat runs every five minutes. Trigger one execution immediately and
inspect its output:

```bash
kubectl create job manual-heartbeat \
  --from=cronjob/gitops-heartbeat \
  --namespace tutorial-cronjob
kubectl logs job/manual-heartbeat --namespace tutorial-cronjob
kubectl delete job manual-heartbeat --namespace tutorial-cronjob
```

The manual Job is deleted because it is not part of Git and the AppProject
reports unmanaged namespace resources as orphans.

## Complex exercises

### Redis: persistent state

Write and read a value, delete the pod, and verify that its replacement can
still read the value from the persistent volume:

```bash
kubectl exec statefulset/redis --namespace tutorial-redis -- \
  redis-cli SET tutorial argocd
kubectl delete pod redis-0 --namespace tutorial-redis
kubectl rollout status statefulset/redis --namespace tutorial-redis
kubectl exec statefulset/redis --namespace tutorial-redis -- \
  redis-cli GET tutorial
```

### Blue/green: switch traffic through Git

The blue and green Deployments run together, while the Service selects blue:

```bash
kubectl port-forward service/color-demo 8084:80 \
  --namespace tutorial-blue-green
curl http://localhost:8084
```

Change `tutorial.argocd.io/track` in `blue-green/service.yaml` from `blue` to
`green`, commit, and push. Argo CD changes the Service selector without
recreating either Deployment.

### Multi-tier: route between services

The frontend serves its own page and proxies `/api/` to two Podinfo backend
replicas through Kubernetes service discovery:

```bash
kubectl port-forward service/frontend 8085:80 \
  --namespace tutorial-multi-tier
curl http://localhost:8085/
curl http://localhost:8085/api/
```

Scale the backend or change the proxy configuration in Git to see Kustomize
generate a new ConfigMap and Argo CD reconcile both tiers.

### Rolling update: preserve availability

Keep requests running while changing the generated page from `v1` to `v2` in
`rolling-update/kustomization.yaml`, then commit and push:

```bash
kubectl port-forward service/rolling-update 8086:80 \
  --namespace tutorial-rolling-update
while true; do curl --silent http://localhost:8086; sleep 1; done
```

The Deployment uses three replicas, `maxUnavailable: 0`, and a
PodDisruptionBudget requiring two available pods. Watch the rollout with:

```bash
kubectl rollout status deployment/rolling-update \
  --namespace tutorial-rolling-update
```

## Remove the optional examples

Delete one track or both. Generated Applications use the Argo CD resources
finalizer, so their managed resources are pruned:

```bash
kubectl delete --filename catalog/simple.yaml
kubectl delete --filename catalog/complex.yaml
# Or remove both tracks:
kubectl delete --kustomize catalog
```

The core `hello-minikube` Application is independent and remains available.
