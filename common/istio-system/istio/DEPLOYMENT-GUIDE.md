# Istio Gateway Deployment for Hetzner Control Plane

## Summary of Changes

This configuration deploys the Istio Ingress Gateway on your Hetzner control plane node (which has internet access via Slack Nebula overlay network) to act as the entry point for web applications hosted on your K3s cluster.

## What Was Added

### 1. Istio Ingress Gateway Deployment
**File**: `common/istio-system/istio/app/istio-ingressgateway.yaml`

- Deploys the Istio gateway on the control plane node using node affinity
- Exposes ports via NodePort:
  - HTTP: 30080 → 80
  - HTTPS: 30443 → 443
- Tolerates control plane taints
- Includes autoscaling (1-3 replicas)

### 2. Updated Gateway Resource
**File**: `common/istio-system/istio/gateway/gateway.yaml`

- Changed HTTPS listener from HTTP to HTTPS protocol
- Added annotations documenting the Hetzner deployment
- Prepared for TLS configuration (commented out)

### 3. Example HTTPRoute
**File**: `common/istio-system/istio/gateway/example-httproute.yaml`

- Demonstrates how to route traffic to applications
- Shows hostname matching and path-based routing
- Includes comments for customization

## How to Use

### 1. Apply the Configuration

If you're using FluxCD (which you are), it will automatically reconcile:

```bash
# Force reconciliation
flux reconcile kustomization istio

# Check status
flux get kustomizations | grep istio
kubectl get pods -n istio-system
```

### 2. Get Your Gateway Access Point

```bash
# Get the Hetzner control plane node IP
kubectl get nodes -o wide | grep control-plane

# The gateway will be accessible at:
# HTTP:  http://<node-ip>:30080
# HTTPS: http://<node-ip>:30443
```

### 3. Route Traffic to Your Application

Create an HTTPRoute in your application directory:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
  namespace: default  # Your app namespace
spec:
  parentRefs:
    - name: external
      namespace: istio-system
      sectionName: http
  hostnames:
    - "myapp.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: my-app-service
          port: 80
```

### 4. Configure DNS

Point your domain to the Hetzner control plane node IP:

```
myapp.example.com. IN A <hetzner-node-ip>
```

Or use `/etc/hosts` for testing:
```
<hetzner-node-ip> myapp.example.com
```

Then access: `http://myapp.example.com:30080`

## Verification Steps

### 1. Check Gateway Deployment

```bash
# Check if ingress gateway is running
kubectl get pods -n istio-system -l app=istio-ingressgateway

# Verify it's on the control plane node
kubectl get pods -n istio-system -l app=istio-ingressgateway -o wide

# Check service
kubectl get svc -n istio-system istio-ingressgateway
```

### 2. Check Gateway Resource Status

```bash
# Check Gateway status
kubectl get gateway -n istio-system external -o yaml

# Look for Programmed condition = True in status
```

### 3. Test Connectivity

```bash
# From within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://istio-ingressgateway.istio-system.svc.cluster.local

# From outside (replace with your node IP)
curl -v http://<hetzner-node-ip>:30080
```

## Optional Configurations

### Use LoadBalancer Instead of NodePort

If you have MetalLB or another load balancer, edit `istio-ingressgateway.yaml`:

```yaml
service:
  type: LoadBalancer
  ports:
    - name: http
      port: 80
      targetPort: 8080
    - name: https
      port: 443
      targetPort: 8443
```

### Enable TLS/HTTPS

1. Create a TLS certificate (using cert-manager):

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gateway-tls
  namespace: istio-system
spec:
  secretName: gateway-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "*.example.com"
    - "example.com"
```

2. Update `gateway.yaml` to enable TLS (uncomment the TLS section)

### Use a Custom Node Label

If you want more control, label your Hetzner node:

```bash
kubectl label node <hetzner-node-name> nebula.gateway=true
```

Then update `istio-ingressgateway.yaml`:

```yaml
nodeSelector:
  nebula.gateway: "true"
```

## Troubleshooting

### Pod Not Scheduling on Control Plane

```bash
# Check node labels
kubectl get nodes --show-labels | grep control-plane

# Check if control plane node has taints
kubectl describe node <control-plane-node> | grep Taints

# Check pod events
kubectl describe pod -n istio-system <gateway-pod-name>
```

### NodePort Not Accessible

1. Check firewall on Hetzner node:
```bash
# On the node
sudo iptables -L -n | grep 30080
sudo iptables -L -n | grep 30443

# Or with firewalld
sudo firewall-cmd --list-ports
```

2. Verify Nebula overlay allows traffic on these ports

3. Check if the service is listening:
```bash
kubectl get svc -n istio-system istio-ingressgateway
```

### Traffic Not Reaching Application

1. Check HTTPRoute:
```bash
kubectl describe httproute <name> -n <namespace>
```

2. Check application service:
```bash
kubectl get svc -n <namespace>
kubectl get endpoints -n <namespace> <service-name>
```

3. Check istio-proxy logs:
```bash
kubectl logs -n istio-system -l app=istio-ingressgateway
```

## Next Steps

1. **Deploy the configuration**: FluxCD will automatically apply it, or manually reconcile
2. **Verify gateway is running**: Check pods and service status
3. **Create HTTPRoutes**: For each application that needs external access
4. **Configure DNS**: Point domains to the Hetzner node IP
5. **Enable TLS**: Use cert-manager for automatic certificate management
6. **Monitor**: Set up monitoring for gateway metrics

## Example Applications

See `common/observability/grafana/` for an example of how to create an HTTPRoute for Grafana:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana
  namespace: observability
spec:
  parentRefs:
    - name: external
      namespace: istio-system
      sectionName: http
  hostnames:
    - "grafana.example.com"
  rules:
    - backendRefs:
        - name: grafana
          port: 80
```

Save this in `common/observability/grafana/app/httproute.yaml` and add it to the kustomization.
