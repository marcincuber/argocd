# argocd
Kubernetes Argo CD Tutorial

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.

It follows the GitOps pattern of using Git repositories as the source of truth for defining the desired application state.

It automates the deployment of the desired application states in the specified target environments. Application deployments can track updates to branches, tags, or be pinned to a specific version of manifests at a Git commit.

## GitOps

GitOps is a set of practices that leverages Git workflows to manage infrastructure and application configurations. By using Git repositories as the source of truth, it allows the DevOps team to store the entire state of the cluster configuration in Git so that the trail of changes are visible and auditable.

GitOps simplifies the propagation of infrastructure and application configuration changes across multiple clusters by defining your infrastructure and applications definitions as “code”.

- Ensure that the clusters have similar states for configuration, monitoring, or storage.
- Recover or recreate clusters from a known state.
- Create clusters with a known state.
- Apply or revert configuration changes to multiple clusters.
- Associate templated configuration with different environments.

## Setup
### Prerequisite CLI Tools

- Git
- Docker
- Minikube `brew install minikube`
- kubectl
- argocd
- kustomize

- yq
- jq
- watch 

## Minikube
### MacOS

```
minikube start --memory=8192 --cpus=4 --kubernetes-version=v1.35.0 --driver=docker -p gitops
```

to make docker the default driver:
```
minikube config set driver docker
```

Expected output should look similar to:
```
[gitops] minikube v1.38.0 on Darwin 26.2 (arm64)
✨  Using the docker driver based on user configuration
❗  Starting v1.39.0, minikube will default to "containerd" container runtime. See #21973 for more info.
📌  Using Docker Desktop driver with root privileges
👍  Starting "gitops" primary control-plane node in "gitops" cluster
🚜  Pulling base image v0.0.49 ...
💾  Downloading Kubernetes v1.35.0 preload ...
    > preloaded-images-k8s-v18-v1...:  243.03 MiB / 243.03 MiB  100.00% 41.86 M
    > gcr.io/k8s-minikube/kicbase...:  478.49 MiB / 478.49 MiB  100.00% 26.90 M
🔥  Creating docker container (CPUs=4, Memory=8192MB) ...
🐳  Preparing Kubernetes v1.35.0 on Docker 29.2.0 ...
🔗  Configuring bridge CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
    ▪ Using image gcr.io/k8s-minikube/storage-provisioner:v5
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "gitops" cluster and "default" namespace by default
```

## Argo CD Installation

In the minikube guide, an Argo CD upstream deployment will be installed and used.

Enable the Ingress Addon for Minikube:
```
minikube addons enable ingress -p gitops
```

Check that the addon has been enabled:
```
💡  ingress is an addon maintained by Kubernetes. For any concerns contact minikube on GitHub.
You can view the list of minikube maintainers at: https://github.com/kubernetes/minikube/blob/master/OWNERS
💡  After the addon is enabled, please run "minikube tunnel" and your ingress resources would be available at "127.0.0.1"
    ▪ Using image registry.k8s.io/ingress-nginx/controller:v1.14.1
    ▪ Using image registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.6.5
    ▪ Using image registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.6.5
🔎  Verifying ingress addon...
🌟  The 'ingress' addon is enabled
```

Install argocd
```
kubectl create namespace argocd
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# or 
cd cluster
kubectl apply --server-side --force-conflicts -k .
```

More info at https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/