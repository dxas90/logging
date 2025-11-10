# Istio Gateway Setup Guide

## Overview

This document describes how to configure Istio Gateway API for ingress traffic management in this GitOps infrastructure.

## Architecture

### Components

1. **Istio Control Plane** (`common/istio-system/istio/`)
   - Manages service mesh and gateway controller
   - Provides GatewayClasses: `istio`, `istio-remote`, `istio-waypoint`

2. **Gateway Resource** (`common/istio-system/gateway/`)
   - Defines ingress entry points for the cluster
   - Configured with HTTP (port 80) and HTTPS (port 443) listeners
   - Allows HTTPRoutes from all namespaces

3. **HTTPRoute Resources** (per-application in `common/<category>/<app>/`)
   - Define routing rules for specific applications
   - Reference the Gateway in their `parentRefs` configuration

## Gateway Configuration

### File Structure
```
common/istio-system/
├── gateway/
│   ├── install.yaml              # FluxCD Kustomization
│   └── app/
│       ├── kustomization.yaml    # App resources
│       └── gateway.yaml          # Gateway resource definition
```

### Gateway Specification

**Location**: `common/istio-system/istio/gateway/gateway.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: external
  namespace: istio-system
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      protocol: HTTPS
      port: 443
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: wildcard-tls
            namespace: cert-manager
```

**Key Configuration Details**:
- **GatewayClass**: `istio` - Uses Istio's gateway controller
- **Listeners**:
  - `http` on port 80 for plain HTTP traffic
  - `https` on port 443 for TLS-terminated traffic
- **AllowedRoutes**: `from: All` allows HTTPRoutes from any namespace to attach
- **TLS Certificate**: References `wildcard-tls` secret from `cert-manager` namespace

### FluxCD Integration

**Location**: `common/istio-system/gateway/install.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: istio-gateway
  namespace: flux-system
spec:
  path: ./common/istio-system/istio/gateway
  targetNamespace: istio-system
  dependsOn:
    - name: istio  # Ensures Istio is installed first
```

## Application Routing

### HTTPRoute Configuration

Applications use the Gateway API's HTTPRoute resource to define their routing rules. The app-template Helm chart automatically creates HTTPRoute resources based on the `route` configuration.

**Example**: `common/default/echo/app/helmrelease.yaml`

```yaml
values:
  route:
    app:
      hostnames: ["{{ .Release.Name }}.example.com"]
      parentRefs:
        - name: external           # Gateway name
          namespace: istio-system  # Gateway namespace (MUST match)
          sectionName: https       # Listener name to use
      rules:
        - backendRefs:
            - identifier: app      # Service identifier
              port: 80             # Service port
```

**Key Points**:
- `parentRefs.name`: Must match the Gateway name (`external`)
- `parentRefs.namespace`: Must be `istio-system` (where Gateway is deployed)
- `sectionName`: References the Gateway listener (`http` or `https`)
- `hostnames`: DNS names for routing (e.g., `echo.example.com`)

### Cross-Namespace Gateway References

The Gateway is in `istio-system`, while applications are in various namespaces (e.g., `default`, `observability`). The Gateway API allows cross-namespace references through:

1. **Gateway Configuration**: `allowedRoutes.namespaces.from: All`
2. **HTTPRoute Configuration**: Explicit `namespace` in `parentRefs`

## Deployment Process

### 1. Gateway Deployment

FluxCD automatically deploys the Gateway when committed to Git:

```bash
# Check Gateway status
kubectl get gateway -n istio-system

# Expected output:
# NAME       CLASS   ADDRESS         PROGRAMMED   AGE
# external   istio   10.96.x.x       True         1m
```

### 2. Verify Gateway Listeners

```bash
kubectl describe gateway external -n istio-system
```

Look for:
- `Programmed` condition = True
- Attached routes count
- Listener status for both `http` and `https`

### 3. Application HTTPRoute Deployment

When an application is deployed, its HTTPRoute automatically attaches to the Gateway:

```bash
# Check HTTPRoutes
kubectl get httproute -A

# Describe specific route
kubectl describe httproute echo -n default
```

**Expected Status**:
```yaml
Status:
  Parents:
    - Conditions:
        - Type: Accepted
          Status: True
        - Type: ResolvedRefs
          Status: True
      ParentRef:
        Name: external
        Namespace: istio-system
```

### 4. Test Connectivity

```bash
# Get Gateway service external IP/port
kubectl get svc -n istio-system -l istio.io/gateway-name=external

# Test HTTP endpoint (if applicable)
curl -H "Host: echo.example.com" http://<GATEWAY-IP>

# Test HTTPS endpoint
curl -H "Host: echo.example.com" https://<GATEWAY-IP> --insecure
```

## Troubleshooting

### Gateway Not Programmed

```bash
# Check Istio controller logs
kubectl logs -n istio-system -l app=istiod

# Verify GatewayClass
kubectl get gatewayclass istio -o yaml
```

### HTTPRoute Not Accepted

**Common Issues**:

1. **Wrong Gateway Namespace**
   ```yaml
   # ❌ Incorrect
   parentRefs:
     - name: external
       namespace: kube-system  # Wrong!

   # ✅ Correct
   parentRefs:
     - name: external
       namespace: istio-system
   ```

2. **Invalid Listener Name**
   ```yaml
   # ❌ Incorrect
   sectionName: tls  # Listener doesn't exist

   # ✅ Correct
   sectionName: https  # Must match Gateway listener name
   ```

3. **Backend Service Not Found**
   ```bash
   # Verify service exists in the same namespace as HTTPRoute
   kubectl get svc -n <namespace>
   ```

### Certificate Issues

```bash
# Verify TLS secret exists
kubectl get secret wildcard-tls -n cert-manager

# Check certificate status (if using cert-manager)
kubectl get certificate -n cert-manager
```

## GitOps Workflow

### Adding New Applications with Routes

1. **Create application structure** following the pattern:
   ```
   common/<category>/<app>/
   ├── install.yaml
   └── app/
       ├── helmrelease.yaml  # Include route configuration
       └── kustomization.yaml
   ```

2. **Configure route in HelmRelease**:
   ```yaml
   values:
     route:
       app:
         hostnames: ["app.example.com"]
         parentRefs:
           - name: external
             namespace: istio-system
             sectionName: https
   ```

3. **Commit and push** - FluxCD handles the rest

### Modifying Gateway Configuration

To add additional listeners or modify settings:

1. Edit `common/istio-system/istio/gateway/gateway.yaml`
2. Commit changes to Git
3. FluxCD reconciles automatically (interval: 1h, or manual trigger)

```bash
# Force reconciliation
flux reconcile kustomization istio-gateway
```

## Security Considerations

### TLS Configuration

- **Mode**: `Terminate` - Gateway terminates TLS, backend traffic is HTTP
- **Certificate**: Managed by cert-manager, stored in `cert-manager` namespace
- **Rotation**: Automatic via cert-manager

### Cross-Namespace References

- Gateway allows routes from all namespaces (`from: All`)
- In production, consider using `from: Selector` with labels for stricter control:
  ```yaml
  allowedRoutes:
    namespaces:
      from: Selector
      selector:
        matchLabels:
          istio-gateway: allowed
  ```

### Network Policies

Consider implementing NetworkPolicies to restrict traffic:
- Only allow ingress to Gateway pods from LoadBalancer
- Only allow egress from Gateway to application services

## References

- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Istio Gateway API Guide](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
- [FluxCD Kustomization](https://fluxcd.io/flux/components/kustomize/kustomization/)
- [bjw-s app-template Chart](https://bjw-s.github.io/helm-charts/docs/app-template/)
