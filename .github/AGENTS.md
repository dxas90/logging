# AI Coding Agent Quick Reference

**Quick start**: Read `.github/copilot-instructions.md` first for comprehensive patterns and conventions.

## 📚 Essential Files (Read First)

1. **`.github/copilot-instructions.md`** — Authoritative repo-specific rules and patterns
2. **`README.md`** — Bootstrap workflow, SOPS setup, multi-cluster overview
3. **`common/README.md`** — Application deployment patterns and categories
4. **`repositories/README.md`** — Legacy→co-located migration examples
5. **`common/istio-system/istio/DEPLOYMENT-GUIDE.md`** — Istio/Gateway API specifics

## 🎯 Common Tasks

### Add New Application

```bash
# 1. Create structure
mkdir -p common/<category>/<app>/app

# 2. Create files (see .github/copilot-instructions.md for templates):
#    - app/kustomization.yaml
#    - app/{oci,helm}repository.yaml
#    - app/helmrelease.yaml
#    - install.yaml

# 3. Update parent
#    Add to common/<category>/kustomization.yaml:
#    resources:
#      - <app>/install.yaml
```

### Troubleshoot Failed Deployment

```bash
# Check Flux status
flux get kustomizations
flux get helmreleases -A

# Describe specific resource
kubectl describe helmrelease <app> -n <namespace>

# Check controller logs
kubectl logs -n flux-system deployment/kustomize-controller
kubectl logs -n flux-system deployment/helm-controller
```

### Validate Changes

```bash
# Reconcile specific Kustomization
flux reconcile kustomization <app>

# Watch reconciliation
flux logs --follow

# Verify deployment
kubectl get pods -n <namespace>
```

## ⚠️ Critical Rules (Quick Reference)

1. **Path format**: Use `./common/<category>/<app>/app` in `install.yaml` (never `./kubernetes/main/...`)
2. **Co-located repos**: Place `{oci,helm}repository.yaml` in `app/` directory (not `repositories/`)
3. **No plaintext secrets**: Use `.sops.yaml` or `clusters/*/vars/cluster-secrets.yaml`
4. **Bootstrap isolation**: Never add apps to `bootstrap/` directory
5. **Parent updates**: Add new `install.yaml` to category's `kustomization.yaml`

## 🔧 Helper Scripts

**`get_secret.sh`**: Fetch secrets from Bitwarden

```bash
./get_secret.sh <field_name>  # Requires bw CLI and unlocked vault
```

## 📦 Repository Type Selection

- **Observability apps** → `ocirepository.yaml` (ghcr.io/bjw-s/helm/app-template)
- **Infrastructure/system** → `helmrepository.yaml` (upstream Helm charts)
- **Custom apps** → Based on upstream availability

## 🔗 Dependency Examples

```yaml
# In install.yaml
spec:
  dependsOn:
    - name: cert-manager
      namespace: flux-system
```

**Common chains**:

- `external-secrets` → `cert-manager` → `vault`
- `kube-prometheus-stack` → `grafana` → `alertmanager`

## 🚦 Reference Examples

**Complete app structure**: `common/observability/grafana/`
**Multi-Kustomization**: `common/cert-manager/` (app + issuers)
**Gateway API**: `common/istio-system/istio/gateway/`

## 🚫 When Blocked

**Missing SOPS age key or Git deploy key?** → Stop and request credentials (never guess/generate)

---

**For detailed patterns, templates, and comprehensive workflows**, see **`.github/copilot-instructions.md`**
