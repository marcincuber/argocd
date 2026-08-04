# Hello application

This example demonstrates Kustomize composition:

- `base` owns the Deployment, Service, and generated content ConfigMap;
- `overlays/local` runs two replicas for the main tutorial;
- `overlays/dev` runs one replica; and
- `overlays/staging` runs three replicas.

Kustomize appends a content hash to `hello-content`. Editing
`base/content/index.html` therefore changes the ConfigMap name referenced by the
Deployment and triggers a rolling update.

Render an environment before committing:

```bash
kubectl kustomize examples/hello-app/overlays/local
kubectl kustomize examples/hello-app/overlays/staging
```

The main Application watches `overlays/local`. The optional ApplicationSet in
`advanced/` generates Applications for the other two overlays.
