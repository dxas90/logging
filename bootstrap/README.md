# Flux CD Kubernetes Cluster Provisioning

This path hold thde files to `bootstrap` the cluster using `kustomize`

## Prerequisites

Before you begin, ensure you have the following:
- A running Kubernetes cluster
- `kubectl` installed and configured
- `flux` CLI installed
- A Git repository for storing cluster configurations
- An SSH key pair for authentication
- `age` key for secret encryption with SOPS (if using SOPS for secret management)

---

## Step 1: Bootstrap Flux CD

Apply the Flux CD bootstrap configuration:

```sh
kubectl apply --kustomize bootstrap
```

This will install Flux CD components in the `flux-system` namespace.
