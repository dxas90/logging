# Repository Definitions (Legacy)

> ⚠️ **Note**: This directory contains legacy repository definitions that are being phased out. New applications should co-locate their repository definitions within their application directories.

## 📁 Directory Structure

```
repositories/
├── helm/                  # Helm repository definitions
│   ├── bitnami.yaml      # Bitnami charts
│   ├── grafana.yaml      # Grafana charts
│   ├── prometheus-community.yaml  # Prometheus community charts
│   └── ...               # Other Helm repositories
├── git/                   # Git repository definitions
│   ├── gateway-api.yaml  # Kubernetes Gateway API
│   └── ...               # Other Git repositories
└── oci/                   # OCI repository definitions
    ├── app-template.yaml # BJW-S app template
    └── ...               # Other OCI repositories
```

## 🔄 Migration to New Structure

### Old Pattern (Legacy)
```
repositories/helm/prometheus-community.yaml  # Central repository definition
common/monitoring/kube-prometheus-stack/
├── ks.yaml                                  # FluxCD Kustomization
└── app/
    └── helmrelease.yaml                     # References external repository
```

### New Pattern (Current)
```
common/monitoring/kube-prometheus-stack/
├── install.yaml                             # FluxCD Kustomization
└── app/
    ├── helmrepository.yaml                  # Co-located repository definition
    ├── helmrelease.yaml                     # Application deployment
    └── kustomization.yaml                   # App resources
```

## 🚀 Benefits of New Structure

1. **Self-Contained Applications**: Each app includes all its dependencies
2. **Simplified Management**: No need to manage central repository files
3. **Better Isolation**: Repository changes don't affect unrelated applications
4. **Easier Debugging**: All application resources are in one location
5. **Consistent Naming**: Repository files named by type (`helmrepository.yaml`, `ocirepository.yaml`)

## 📋 Repository Types

### Helm Repositories
Standard Helm chart repositories:
- **bitnami**: Bitnami application charts
- **grafana**: Grafana and observability charts
- **prometheus-community**: Prometheus ecosystem charts
- **jetstack**: Cert-manager and related tools
- **traefik**: Traefik proxy and ingress charts

### OCI Repositories
Container registry hosted charts:
- **app-template**: BJW-S application template for custom apps
- **dragonfly-operator**: Dragonfly Redis-compatible operator

### Git Repositories
Git-hosted Kubernetes manifests:
- **gateway-api**: Kubernetes Gateway API CRDs and controllers

## 🔧 Migration Guide

When migrating an application from the legacy structure:

1. **Copy Repository Definition**:
   ```bash
   cp repositories/helm/example.yaml common/my-app/app/helmrepository.yaml
   ```

2. **Update App Kustomization**:
   ```yaml
   # common/my-app/app/kustomization.yaml
   resources:
     - helmrepository.yaml  # Add repository reference
     - helmrelease.yaml
   ```

3. **Create Install Configuration**:
   ```yaml
   # common/my-app/install.yaml
   apiVersion: kustomize.toolkit.fluxcd.io/v1
   kind: Kustomization
   metadata:
     name: my-app
   spec:
     path: ./kubernetes/main/apps/my-app/app
     # ... rest of configuration
   ```

4. **Update Parent Kustomization**:
   Replace `my-app/ks.yaml` with `my-app/install.yaml`

5. **Remove Legacy Files**:
   - Delete `my-app/ks.yaml`
   - Update any references to the central repository

## 🗑️ Deprecation Timeline

The legacy repository structure will be maintained for compatibility but is considered deprecated:

- **Phase 1** ✅: New applications use co-located repositories
- **Phase 2** ✅: Existing applications migrated to new structure
- **Phase 3** 🔄: Legacy repository definitions marked as deprecated
- **Phase 4** 📅: Legacy repository definitions removed (future)

## 📚 References

For more information about the new application structure, see:
- [Common Applications README](../common/README.md)
- [Main Project Documentation](../README.md)
- [FluxCD Documentation](https://fluxcd.io/docs/)

---

> 💡 **Tip**: When creating new applications, always use the new co-located repository pattern for better maintainability and isolation.
