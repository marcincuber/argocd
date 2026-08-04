# Private repository authentication

Argo CD runs inside Minikube and does not inherit credentials from your local
Git client. Register private repository credentials before `make bootstrap`.
Keep tokens and private keys out of Git.

Start the Argo CD port-forward and log in first:

```bash
make port-forward-argocd
```

## HTTPS token

In another terminal, read the token without echoing it and register the
repository:

```bash
read -r -s -p "Git token: " GIT_TOKEN
echo
argocd repo add https://github.com/USER/PRIVATE-REPO.git \
  --username git \
  --password "${GIT_TOKEN}"
unset GIT_TOKEN

make bootstrap \
  REPO_URL=https://github.com/USER/PRIVATE-REPO.git \
  REVISION=main
```

Use a fine-grained, read-only token limited to this repository. The username
required by a provider may differ; consult its Argo CD repository guidance.

## SSH deploy key

Register a read-only deploy key with the Git provider, then add the SSH URL:

```bash
argocd repo add git@github.com:USER/PRIVATE-REPO.git \
  --ssh-private-key-path "${HOME}/.ssh/argocd_deploy_key"

make bootstrap \
  REPO_URL=git@github.com:USER/PRIVATE-REPO.git \
  REVISION=main
```

The bootstrap script preserves an explicitly supplied SSH URL. When it derives
a common GitHub SSH `origin` automatically, it converts it to HTTPS for the
public-repository beginner path.

## Verify and remove credentials

```bash
argocd repo list
argocd repo get https://github.com/USER/PRIVATE-REPO.git
argocd repo rm https://github.com/USER/PRIVATE-REPO.git
```

Repository credentials are stored as Kubernetes Secrets in the `argocd`
namespace. Treat access to that namespace as sensitive. For shared or
production installations, prefer workload identity or narrowly scoped
credential templates and integrate an approved secret-management system.
