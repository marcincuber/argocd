# Advanced learning track

Complete the main `hello-minikube` tutorial before this track.

## Kustomize base and overlays

The shared base contains one-replica defaults. Each overlay changes only what is
environment-specific:

| Overlay | Namespace | Replicas | Created by |
| --- | --- | ---: | --- |
| `local` | `hello-minikube` | 2 | Main Application |
| `dev` | `hello-dev` | 1 | ApplicationSet |
| `staging` | `hello-staging` | 3 | ApplicationSet |

Compare the rendered output:

```bash
kubectl kustomize examples/hello-app/overlays/dev
kubectl kustomize examples/hello-app/overlays/staging
```

The base uses `configMapGenerator`. Kustomize rewrites the Deployment reference
to a hashed ConfigMap name, so a content change modifies the pod template and
triggers a rollout.

## Generate multiple Applications with ApplicationSet

Ensure the advanced files are committed and pushed, then run:

```bash
make advanced
kubectl get applicationsets,applications --namespace argocd
```

The `hello-environments` ApplicationSet turns two list elements into two Argo CD
Applications. Wait for both:

```bash
argocd app wait hello-dev --sync --health --timeout 300
argocd app wait hello-staging --sync --health --timeout 300
kubectl get deployments --namespace hello-dev
kubectl get deployments --namespace hello-staging
```

To add `qa`, create `overlays/qa`, add a `qa` list element to
`advanced/environments.yaml`, commit, and push. The ApplicationSet controller
creates the additional Application automatically.

Remove the advanced track without affecting the main Application:

```bash
kubectl delete -k advanced
```

The generated Applications are deleted with the ApplicationSet. Confirm the
result before manually removing any remaining namespaces.

## Optional Git webhook

Polling is reliable and requires no extra service. A webhook reduces detection
latency but GitHub must reach the Argo CD API server. For a temporary local lab:

1. Run `make port-forward-argocd`.
2. Expose local port 8080 through a trusted HTTPS tunnelling tool.
3. Create a long random webhook secret.
4. Store it in `argocd-secret` under `webhook.github.secret`.
5. Configure a GitHub push webhook to `https://PUBLIC-URL/api/webhook` with
   content type `application/json` and the same secret.

Example secret update:

```bash
read -r -s -p "Webhook secret: " WEBHOOK_SECRET
echo
kubectl patch secret argocd-secret \
  --namespace argocd \
  --type merge \
  --patch "{\"stringData\":{\"webhook.github.secret\":\"${WEBHOOK_SECRET}\"}}"
unset WEBHOOK_SECRET
```

Do not expose Argo CD without authentication or reuse the administrator
password as a webhook secret. Stop the tunnel after the exercise. The tutorial
continues to work through polling when no webhook is configured.

## Production-oriented next steps

- Replace the broad namespace resource allowlist with explicit kinds.
- Create separate projects for teams or trust boundaries.
- Configure SSO and Argo CD RBAC, then disable the built-in administrator.
- Use ingress with trusted TLS instead of port forwarding.
- Add signed commits or Git tag verification and admission policies.
- Use pull requests, protected branches, required CI, and CODEOWNERS.
- Evaluate the HA Argo CD manifest for a production control plane.
