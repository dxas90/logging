# FluxCD GitOps Infrastructure — AI Assistant Instructions

**Purpose**: Provide actionable, repo-specific guidance for AI coding agents working with this FluxCD + Kustomize infrastructure.

## 🏗️ Architecture Quick Start

**Directory hierarchy**: `bootstrap/` → `clusters/<type>/` → `common/<category>/<app>/`

- **`bootstrap/`**: FluxCD installation only — keep minimal, never add applications here
- **`clusters/<type>/`**: Environment-specific config (k3d, kind, aws, azure, gcp, metal)
  - `flux-system/gotk-sync.yaml`: FluxCD sync configuration
  - `vars/cluster-settings.yaml`: Environment variables (ConfigMap)
  - `vars/cluster-secrets.yaml`: Encrypted secrets (SOPS)
- **`common/<category>/<app>/`**: Shared infrastructure applications
  - Categories: `cert-manager`, `external-secrets`, `kube-system`, `kube-tools`, `observability`, `networking`, `dbms`, `istio-system`, `keda`
  - Each app follows strict co-located repository pattern (see below)

## 🔒 Critical Conventions (Must Follow)

### 1. Co-located Repository Pattern
**Every app MUST include its own repository definition in the `app/` directory:**

```yaml
# Example: common/observability/grafana/app/
├── kustomization.yaml       # Resources: ocirepository.yaml, helmrelease.yaml
├── ocirepository.yaml       # Co-located repository (or helmrepository.yaml)
└── helmrelease.yaml         # Application deployment
```

**Never reference** the legacy `repositories/` directory — it's being phased out.

### 2. FluxCD Kustomization Paths
**`install.yaml` paths MUST be relative to repo root:**

```yaml
# ✅ CORRECT: common/observability/grafana/install.yaml
spec:
  path: ./common/observability/grafana/app

# ❌ WRONG - legacy paths
spec:
  path: ./kubernetes/main/apps/grafana/app
```

### 3. Secret Management
- **SOPS encryption**: Secrets end with `.sops.yaml` suffix
- **Cluster secrets**: Store in `clusters/<type>/vars/cluster-secrets.yaml`
- **Never commit plaintext secrets** — if blocked, request SOPS age key
- **Variable substitution**: FluxCD postBuild interpolates from cluster-settings/cluster-secrets

## 📝 Standard Application Pattern

### Adding a New Application

**1. Create directory structure:**
```bash
mkdir -p common/<category>/<app-name>/app
```

**2. Repository definition** (choose one based on upstream):
```yaml
# app/helmrepository.yaml (for traditional Helm charts)
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: <app-name>
  namespace: flux-system
spec:
  interval: 1h
  url: https://charts.example.com/

# OR app/ocirepository.yaml (preferred for observability apps)
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: OCIRepository
metadata:
  name: <app-name>
  namespace: flux-system
spec:
  interval: 12h
  url: oci://ghcr.io/bjw-s/helm/app-template
  ref:
    tag: 3.7.0
```

**3. App resources kustomization:**
```yaml
# app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ocirepository.yaml  # or helmrepository.yaml
  - helmrelease.yaml
```

**4. FluxCD Kustomization:**
```yaml
# install.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: <app-name>
  namespace: flux-system
spec:
  targetNamespace: <namespace>
  path: ./common/<category>/<app-name>/app
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  prune: true
  wait: true
  interval: 1h
  timeout: 5m
```

**5. Update parent kustomization:**
```yaml
# common/<category>/kustomization.yaml
resources:
  - <app-name>/install.yaml  # Add this line
```

### Repository Type Conventions
- **Observability apps**: Prefer `ocirepository.yaml` (ghcr.io/bjw-s/helm/app-template)
- **Infrastructure/system**: Use `helmrepository.yaml` based on upstream availability
- **Databases**: Individual namespaces (`cloudnative-pg`, `database`)

### Namespace Strategy
- **Observability**: Single `observability` namespace for monitoring/logging
- **System components**: Dedicated namespaces (`kube-system`, `cert-manager`, `kyverno`, etc.)

## 🔗 Dependency Management

**Use `dependsOn` in install.yaml for explicit ordering:**
```yaml
spec:
  dependsOn:
    - name: cert-manager
      namespace: flux-system
    - name: external-secrets
      namespace: flux-system
```

**Common dependency chains:**
- `external-secrets` → `cert-manager` → `vault`
- `kube-prometheus-stack` → `grafana` → `alertmanager`
- `cilium` → `coredns` → `metrics-server`

## 🐛 Debugging & Validation Commands

### FluxCD Status
```bash
flux get kustomizations              # View all Kustomizations
flux get helmreleases                # View all HelmReleases
flux reconcile kustomization <name>  # Force reconciliation
flux logs --follow                   # Stream Flux logs
```

### Application Troubleshooting
```bash
kubectl describe helmrelease <app> -n <namespace>
kubectl logs -n flux-system deployment/kustomize-controller
kubectl logs -n flux-system deployment/helm-controller
kubectl logs -n flux-system deployment/source-controller
```

### Deployment
```bash
kubectl apply --kustomize bootstrap       # Bootstrap FluxCD
kubectl apply --kustomize clusters/k3d    # Apply cluster config (replace k3d)
```

## 🚪 Gateway API / Istio Integration

**Gateway resource**: `common/istio-system/istio/gateway/gateway.yaml`

**HTTPRoute parentRefs must reference:**
- `name: external`
- `namespace: istio-system`
- `sectionName: http` or `https` (matching Gateway listener)

**Ingress gateway specifics:**
- Deployed with node affinity to control plane
- NodePort service (30080/30443)
- See `common/istio-system/istio/DEPLOYMENT-GUIDE.md` for details

## 📋 Code Review Checklist

Before submitting changes, verify:

- [ ] `install.yaml` uses correct path: `./common/<category>/<app>/app`
- [ ] Repository definition is co-located in `app/` directory
- [ ] Parent category `kustomization.yaml` includes new `install.yaml`
- [ ] No plaintext secrets committed (use `.sops.yaml` or cluster-secrets)
- [ ] `bootstrap/` directory remains minimal (no apps)
- [ ] Dependencies declared with `dependsOn` if required
- [ ] Namespace matches category conventions

**PR description should include validation commands run:**
```bash
flux reconcile kustomization <app>
kubectl describe helmrelease <app> -n <namespace>
# Include output showing successful reconciliation
```

## 🔍 Key Files Reference

**Must read before editing:**
- `common/README.md` — Standard application patterns
- `README.md` — Bootstrap, SOPS, multi-cluster setup
- `repositories/README.md` — Legacy pattern migration guide
- `common/istio-system/istio/DEPLOYMENT-GUIDE.md` — Istio/Gateway specifics

**Examples to copy/reference:**
- `common/observability/grafana/` — Complete OCI-based app
- `common/cert-manager/` — Multi-Kustomization with dependencies
- `common/istio-system/istio/gateway/` — Gateway API usage

## 🚫 When Blocked

**If you need:**
- SOPS age key for secret decryption
- Git deploy key for repository access
- Cluster access credentials

**→ Stop and request the key** — do not attempt to generate or guess values.

**Prefer configuration-only edits** when runtime access is unavailable.
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
   apiVersion: source.toolkit.fluxcd.io/v1
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
