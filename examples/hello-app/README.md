# Hello application

This directory is the Git source watched by the `hello-minikube` Argo CD
Application in [`../../bootstrap/hello-minikube.yaml`](../../bootstrap/hello-minikube.yaml).

Change a manifest here, commit it, and push it to `main`. Argo CD will detect
the new commit and reconcile the `hello-minikube` namespace automatically.

Good first changes are:

- edit the text in `configmap.yaml`;
- change `replicas` in `deployment.yaml`; or
- add a new Kubernetes manifest to `resources` in `kustomization.yaml`.

Run `kubectl kustomize examples/hello-app` from the repository root to render
and inspect the Kubernetes objects before committing.
