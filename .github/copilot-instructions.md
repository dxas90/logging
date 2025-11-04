# GitOps Kubernetes Infrastructure - AI Coding Assistant Instructions

## 🏗️ Architecture Overview

This is a **FluxCD-based GitOps infrastructure** repository managing Kubernetes clusters across multiple environments. The architecture follows strict patterns for declarative infrastructure management.

### Key Architectural Concepts
- **GitOps Pattern**: All cluster state is managed through Git commits, FluxCD handles reconciliation
- **Multi-cluster Design**: Support for k3d, kind, AWS EKS, Azure AKS, GCP GKE environments
- **Hierarchical Structure**: `bootstrap/ → clusters/ → common/` with progressive complexity
- **Co-located Repositories**: Each app includes its own repository definitions (moved from centralized `repositories/`)

## 📁 Critical Directory Structure

```
bootstrap/                  # FluxCD installation only - minimal and stable
clusters/<type>/           # Environment-specific configuration
├── flux-system/          # FluxCD system manifests (gotk-sync.yaml)
└── vars/                 # cluster-settings.yaml + cluster-secrets.yaml (SOPS)
common/                    # Shared infrastructure applications
├── <category>/           # cert-manager, kube-system, observability, etc.
│   └── <app>/
│       ├── install.yaml  # FluxCD Kustomization (CRITICAL: use ./common/<category>/<app>/app paths)
│       └── app/
│           ├── kustomization.yaml     # App resources
│           ├── {helm,oci,git}repository.yaml  # Co-located repo definition
│           └── helmrelease.yaml       # Application deployment
```

## 🔄 Application Deployment Pattern

**Every application follows this exact pattern:**

1. **Repository Co-location** (NEW PATTERN):
   ```yaml
   # app/helmrepository.yaml or app/ocirepository.yaml
   apiVersion: source.toolkit.fluxcd.io/v1beta2
   kind: HelmRepository  # or OCIRepository
   ```

2. **FluxCD Kustomization** (install.yaml):
   ```yaml
   # CRITICAL: Path must be relative to repo root
   spec:
     path: ./common/<category>/<app>/app  # NOT ./kubernetes/main/apps/...
     targetNamespace: <namespace>
     dependsOn: [...]  # Explicit dependencies
   ```

3. **App Resources** (app/kustomization.yaml):
   ```yaml
   resources:
     - ocirepository.yaml  # Prefer OCI over Helm for observability apps
     - helmrelease.yaml
     - [secrets.yaml, configmaps, etc.]
   ```

## 🎯 Development Workflows

### Adding New Applications
1. **Choose appropriate category**: `common/{cert-manager,kube-system,kube-tools,observability,networking,dbms,vault}`
2. **Follow co-located pattern**: Create `app/{oci,helm}repository.yaml` alongside `helmrelease.yaml`
3. **Update parent kustomization**: Add `- new-app/install.yaml` to category's `kustomization.yaml`
4. **Set correct paths**: Use `./common/<category>/<app>/app` in `install.yaml`

### Secret Management
- **External Secrets**: Apps use ExternalSecret CRDs referencing ClusterSecretStore
- **SOPS Encryption**: Cluster secrets in `clusters/<type>/vars/cluster-secrets.yaml`
- **Variable Substitution**: FluxCD postBuild substitutes from cluster-settings/cluster-secrets

### Debugging Commands
```bash
# FluxCD status
flux get kustomizations
flux get helmreleases
flux reconcile kustomization <name>

# Application troubleshooting
kubectl describe helmrelease <app> -n <namespace>
kubectl logs -n flux-system deployment/kustomize-controller
```

## 🔧 Project-Specific Conventions

### Repository Types by Category
- **Observability apps**: Prefer `ocirepository.yaml` (ghcr.io/bjw-s/helm/app-template)
- **Infrastructure**: Use `helmrepository.yaml` (traditional Helm charts)
- **System components**: Mix based on upstream availability

### Namespace Strategy
- **Observability**: Single `observability` namespace for all monitoring/logging
- **System**: `kube-system`, `kyverno`, `cert-manager` etc. per component
- **Databases**: Individual namespaces (`cloudnative-pg`, `database`)

### Dependency Management
Common dependency chains:
```yaml
external-secrets → cert-manager → vault
kube-prometheus-stack → grafana → alertmanager
cilium → coredns → metrics-server
```

## ⚠️ Critical Path Requirements

1. **Never hardcode Git paths**: Use `./common/<category>/<app>/app` not `./kubernetes/main/apps/...`
2. **Repository co-location mandatory**: No references to `repositories/` directory (legacy)
3. **SOPS encryption required**: Any secrets must use `.sops.yaml` suffix
4. **Bootstrap isolation**: Keep `bootstrap/` minimal - only FluxCD components
5. **Cluster vars pattern**: Environment-specific config goes in `clusters/<type>/vars/`

## 🔍 Integration Points

### FluxCD Controllers
- **source-controller**: Manages Git/Helm/OCI repositories
- **kustomize-controller**: Applies Kustomizations with SOPS decryption
- **helm-controller**: Manages HelmReleases

### External Dependencies
- **SOPS + age**: Secret encryption (cluster-secrets require age key)
- **External Secrets Operator**: Integration with external secret stores
- **Kustomize**: Configuration management and environment overlays

This codebase prioritizes **GitOps declarative management** over imperative changes. All modifications should be committed to Git for FluxCD reconciliation.
