# Flux CD Kubernetes Cluster Provisioning

This repository implements a GitOps approach for managing Kubernetes clusters using FluxCD. It organizes applications, infrastructure, and cluster configurations in a structured manner to facilitate continuous deployment and automated cluster management.

This guide provides step-by-step instructions to provision a Kubernetes cluster using Flux CD.
An extended implementation of [flux2-kustomize-helm](https://github.com/fluxcd/flux2-kustomize-helm-example)

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

---

## Step 2: Create Flux System Secret

Create a Kubernetes secret to allow Flux to authenticate with your Git repository:

```sh
kubectl create secret generic flux-system \
    --namespace=flux-system \
    --from-file=identity=<PRIVATE_KEY_PATH> \
    --from-file=identity.pub=<PUBLIC_KEY_PATH> \
    --from-literal=known_hosts="$(ssh-keyscan -p <PORT|22> <GIT_REPO_HOST> 2>/dev/null | grep -v '^#')"
```

Replace:
- `<PRIVATE_KEY_PATH>` with the path to your private SSH key
- `<PUBLIC_KEY_PATH>` with the path to your public SSH key
- `<PORT|22>` with the SSH port of your Git server (default: `22`)
- `<GIT_REPO_HOST>` with the hostname of your Git repository server

---

## Step 3: Create SOPS Age Secret (Optional)

If you are using SOPS for secret encryption, store the Age key as a Kubernetes secret:

```sh
cat <YOUR_AGE_KEY_FILE> | kubectl -n flux-system create secret generic sops-age --from-file=age.agekey=/dev/stdin
```

Replace `<YOUR_AGE_KEY_FILE>` with the path to your Age key file.

---

## Next Steps

Once these steps are completed:
- Verify Flux components are running:
  ```sh
  kubectl get pods -n flux-system
  ```
- Check the Flux logs for any errors:
  ```sh
  kubectl logs -n flux-system deployment/flux-system
  ```
- Confirm that the cluster is syncing with your Git repository.

For further configurations, refer to the [Flux CD documentation](https://fluxcd.io/docs/).

---

## Repository Structure

### `apps/`
Contains application manifests managed using Kustomize. Applications are categorized into different environments:
- `base/` - Base configuration for all applications.
- `development/`, `staging/`, `production/`, `testing/` - Environment-specific overlays for applications.

### `bootstrap/`
Contains bootstrapping configurations for initializing FluxCD on a cluster.

### `clusters/`
Defines the Kubernetes clusters managed by FluxCD, including:
- `docker-desktop-kind/`
- `k3d/`
- `production/`, `staging/`, `testing/`

Each cluster includes:
- `flux-system/` - FluxCD system manifests.
- `vars/` - Cluster-specific settings and secrets.

### `infrastructure/`
Manages core infrastructure components deployed to Kubernetes:
- `base/` - Common infrastructure components.
- `development/`, `staging/`, `production/`, `testing/` - Environment-specific overlays.

Includes HelmReleases for managing:
- Networking (Traefik, Nginx, MetalLB, Cilium)
- Monitoring (Prometheus, Grafana, Gatus, Goldilocks)
- Security (Kyverno, External Secrets, Cert-Manager)

### `repositories/`
Defines external dependencies, such as Git and Helm repositories:
- `git/` - External Git repositories.
- `helm/` - Helm repositories for third-party applications.
- `oci/` - OCI-based Flux manifests.

## FluxCD Workflow
1. **Bootstrap FluxCD**: Apply configurations in `bootstrap/` to set up Flux on a cluster.
2. **Manage Clusters**: Define cluster-specific configurations in `clusters/`.
3. **Deploy Applications**: Update `apps/` to manage application releases.
4. **Manage Infrastructure**: Update `infrastructure/` for Kubernetes platform services.
5. **Sync with FluxCD**: Flux continuously reconciles cluster state with this repository.

## Contributing
- Ensure all changes are reviewed before merging.
- Follow GitOps best practices for managing resources.
- Use Kustomize overlays to manage environment-specific settings.

## License
This repository is licensed under the MIT License.


## Troubleshooting

- If Flux fails to authenticate with the Git repository, verify the SSH keys and `known_hosts` configuration.
- Check the `flux-system` logs for errors related to Git authentication.
- Ensure your cluster has internet access if pulling manifests from an external source.

---

## References

- [Flux CD Documentation](https://fluxcd.io/docs/)
- [SOPS for Kubernetes](https://fluxcd.io/flux/guides/mozilla-sops/)


### General setup

```shell
  export CLUSTER=kind
  kubectl apply --kustomize bootstrap ; \
  cat $HOME/.config/sops/age/keys.txt | kubectl -n flux-system create secret generic sops-age --from-file=age.agekey=/dev/stdin ; \
  kubectl create secret generic flux-system \
    --namespace=flux-system \
    --from-file=identity=$HOME/Vaults/Safe/flux/fleet-flux-github \
    --from-file=identity.pub=$HOME/Vaults/Safe/flux/fleet-flux-github.pub \
    --from-literal=known_hosts="$(ssh-keyscan -p 4022 gitea.dxas90.work 2>/dev/null | grep -v '^#')" ; \
  sops --decrypt clusters/${CLUSTER}/vars/cluster-secrets.sops.yaml | kubectl apply -f - ; \
  envsubst < clusters/${CLUSTER}/vars/cluster-settings.yaml | kubectl apply -f - ; \
  kubectl apply -k clusters/${CLUSTER}
```
---
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-demo
spec:
  service_type: clusterip
  ingress_type: ingress
  ingress_hosts:
    - hostname: awx-demo.example.com
  ingress_annotations: |
    environment: testing
