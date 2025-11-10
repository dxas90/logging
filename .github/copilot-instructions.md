# GitOps FluxCD infrastructure — AI assistant notes

Purpose: give concise, repo-specific guidance so an AI coding agent can make correct, low-risk edits.

Top-level architecture (quick): this repo is FluxCD + Kustomize driven. Key dirs:
- `bootstrap/` — minimal FluxCD bootstrap (do not add application installs here).
- `clusters/<type>/vars/` — cluster-settings.yaml and SOPS-encrypted cluster-secrets.yaml (per-cluster overrides).
- `common/<category>/<app>/` — application installs. Each app follows the co-located pattern below.

Core conventions you must follow
- Co-located repositories: every app MUST place `app/helmrepository.yaml` or `app/ocirepository.yaml` next to `app/helmrelease.yaml` and `app/kustomization.yaml`.
- `install.yaml` CRs (in `common/<category>/<app>/install.yaml`) must use spec.path relative to repo root: `./common/<category>/<app>/app` (never `./kubernetes/main/...`).
- Secrets: use SOPS (`*.sops.yaml`) and store cluster keys in `clusters/<type>/vars/cluster-secrets.yaml`. Do not commit plaintext secrets.

Deployment & debugging commands (use when validating edits):
- Bootstrap Flux: `kubectl apply --kustomize bootstrap`
- Apply a cluster: `kubectl apply --kustomize clusters/k3d` (replace k3d)
- Flux status / reconcile:
  - `flux get kustomizations`
  - `flux get helmreleases`
  - `flux reconcile kustomization <name>`
  - `kubectl describe helmrelease <app> -n <namespace>`

Patterns & examples (copy/paste safe)
- App layout (example): `common/observability/grafana/app/{kustomization.yaml,ocirepository.yaml,helmrelease.yaml}` and `common/observability/grafana/install.yaml`.
- Gateway / Istio: Gateway resource lives at `common/istio-system/gateway/app/gateway.yaml`. HTTPRoute parentRefs must point to name `external` and namespace `istio-system` and match listener sectionName (http/https).

Integration points & external deps
- Flux controllers (source, kustomize, helm) manage reconciliation.
- SOPS + age for secret encryption; External Secrets Operator and Vault integrations present.

Editing rules for AI agents (must obey)
1. Never add or modify secrets inline; create `.sops.yaml` encrypted file or update `clusters/*/vars/cluster-secrets.yaml`.
2. Follow co-located repository pattern; if you must migrate a legacy `repositories/` entry, also add the matching `install.yaml` and update parent kustomization.
3. Keep `bootstrap/` minimal — no application kustomizations there.
4. When changing an `install.yaml` path, update the parent category `kustomization.yaml` to include the new `install.yaml`.

Files to inspect first (priority):
- `common/README.md` — app patterns
- `README.md` (repo root) — quick start, bootstrapping and SOPS usage
- `bootstrap/README.md` and `clusters/*/vars/*.yaml` for cluster-specific behavior

Validation & notes for PRs
- If a change affects runtime, include a short validation note in the PR body listing the Flux/kubectl commands you ran (e.g. `flux reconcile ...`, `kubectl describe ...`).
- Prefer configuration-only, low-risk edits when keys or runtime access are missing.

When blocked
- If a change needs the SOPS age key or Git deploy key, stop and request the secret (do not attempt to guess or create one).

Offer to add: a PR checklist template (reconcile + SOPS checks) if the maintainer wants it.
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
