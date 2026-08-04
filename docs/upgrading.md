# Upgrade and rollback Argo CD

Patch upgrades should still be reviewed and tested. For minor or major upgrades,
read every intermediate Argo CD upgrade guide before changing the pin.

## Preview and apply the current pin

The safe upgrade command verifies the active context, runs `kubectl diff`, asks
for confirmation, applies the installer, waits for every rollout, and prints the
installed server image:

```bash
make upgrade
```

In automation, make the confirmation explicit:

```bash
CONFIRM_UPGRADE=true make upgrade
```

## Change the pin manually

1. Update `ARGOCD_VERSION` in `.versions.env`.
2. Update the version in `cluster/kustomization.yaml`.
3. Update the tested-version table in `README.md`.
4. Read the release notes and relevant upgrade guide.
5. Render and validate before touching the cluster.

```bash
make render
make validate
make upgrade
make verify
```

Renovate is configured to update the related version locations in one grouped
pull request when its GitHub app is enabled.

## Verify after an upgrade

```bash
kubectl get pods --namespace argocd
kubectl get deployment argocd-server \
  --namespace argocd \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
argocd version
make verify
```

The CLI and server do not have to use the identical patch version, but keeping
them close avoids feature-skew surprises.

## Roll back the installer

If a patch upgrade fails in this disposable environment, restore the previous
version in all three pin locations and run `make upgrade` again. Do not assume a
downgrade is safe across CRD or database migrations; consult the release's
upgrade documentation first.

For the application itself, use `git revert` and push. Automated sync will
reconcile that reverted desired state. Avoid treating manual live edits as a
rollback because self-healing will undo them.
