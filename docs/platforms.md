# Platform setup

The Makefile and scripts use Bash. macOS, Linux, and Windows Subsystem for Linux
(WSL) provide the smoothest experience. Native Windows users can run the manual
commands from the main tutorial in PowerShell, but should use WSL for the
automation scripts.

## macOS

Install the CLI tools with Homebrew:

```bash
brew install git make kubectl minikube argocd
```

Install Docker Desktop or use Podman. Both Intel and Apple Silicon are
supported. Verify that the container engine has at least 6 GiB available for
the default tutorial configuration.

## Linux and WSL

The commands below install pinned `kubectl` and Argo CD binaries and the latest
stable Minikube binary on x86-64 Linux. Use the corresponding `arm64` assets on
ARM64 systems.

```bash
curl -fsSLO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install -m 0755 minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

curl -fsSLO https://dl.k8s.io/release/v1.36.3/bin/linux/amd64/kubectl
curl -fsSLO https://dl.k8s.io/release/v1.36.3/bin/linux/amd64/kubectl.sha256
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl kubectl.sha256

curl -fsSLO https://github.com/argoproj/argo-cd/releases/download/v3.5.0/argocd-linux-amd64
sudo install -m 0755 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

Install Git, Make, and either Docker Engine or Podman through the distribution's
package manager.

When using WSL, enable Docker Desktop's WSL integration or install a container
engine inside the distribution. Keep the repository in the Linux filesystem for
faster file operations.

## Windows

In an elevated PowerShell terminal:

```powershell
winget install --exact --id Git.Git
winget install --exact --id Kubernetes.kubectl
winget install --exact --id Kubernetes.minikube
winget install --exact --id Docker.DockerDesktop
```

Install the pinned Argo CD CLI:

```powershell
$version = "v3.5.0"
$url = "https://github.com/argoproj/argo-cd/releases/download/$version/argocd-windows-amd64.exe"
New-Item -ItemType Directory -Force -Path "$env:LOCALAPPDATA\argocd" | Out-Null
Invoke-WebRequest -Uri $url -OutFile "$env:LOCALAPPDATA\argocd\argocd.exe"
```

Add `%LOCALAPPDATA%\argocd` to `PATH`, restart the terminal, and verify
`argocd version --client`. WSL is recommended if you want to use `make all`.

## Podman instead of Docker

Start the Podman machine on macOS or Windows, then select the driver:

```bash
podman machine init --cpus 4 --memory 6144
podman machine start
make doctor DRIVER=podman
make cluster DRIVER=podman
```

On Linux, ensure rootless Podman networking works before starting Minikube.
Keep using the same `DRIVER=podman` override when recreating the profile.

## Lower-resource computers

Argo CD can run with less memory for a small example, although startup and image
pulls will be slower:

```bash
make cluster CPUS=3 MEMORY=4096
```

Avoid running unrelated local Kubernetes clusters at the same time. If pods
remain `Pending`, inspect node allocation with:

```bash
kubectl describe node argocd
kubectl top nodes
```

The metrics command requires the optional Minikube metrics-server addon.
