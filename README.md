# Cloud Native LGTM Stack

[![TDC](https://img.shields.io/badge/TDC-Workshop-FF6B6B?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTEyIDJMMTMuMDkgOC4yNkwyMSA5TDEzLjA5IDE1Ljc0TDEyIDIyTDEwLjkxIDE1Ljc0TDMgOUwxMC45MSA4LjI2TDEyIDJaIiBmaWxsPSJ3aGl0ZSIvPgo8L3N2Zz4K)](https://thedevconf.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Grafana](https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=grafana&logoColor=white)](https://grafana.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Helm](https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white)](https://helm.sh/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Workshop](https://img.shields.io/badge/Type-Educational-purple?style=for-the-badge&logo=graduation-cap)]()
[![Brazil](https://img.shields.io/badge/Made_in-Brazil-009739?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjI0IiBoZWlnaHQ9IjI0IiBmaWxsPSIjMDA5NzM5Ii8+Cjwvc3ZnPgo=)](#)

🇧🇷 **Created for TDC (The Developers Conference) Workshop Attendees**

A complete, lightweight, cloud-native observability stack optimized for single-node Kubernetes environments. This project was designed for the **Cloud Native Observability Workshop** at TDC Brazil, providing workshop attendees with a hands-on learning environment to explore the LGTM stack.

Perfect for learning, experimentation, and understanding how modern observability works in cloud-native environments.

> **✅ Cross-Platform Validated**: All PowerShell scripts have been tested and verified to work on both Linux (Ubuntu with PowerShell 7.5+) and Windows environments, ensuring consistent functionality across platforms.

## 🏗️ Architecture

**LGTM Stack Components:**
- **L**oki - Log aggregation system
- **G**rafana - Visualization and dashboards
- **T**empo - Distributed tracing system
- **M**imir - Metrics storage (Prometheus-compatible)

**Supporting Components:**
- **Alloy** - Unified observability data collector (Grafana Agent)
- **Minio** - Object storage backend (S3-compatible)
- **Kube-state-metrics** - Kubernetes cluster state metrics
- **Node-exporter** - System-level metrics (Docker Desktop compatible)

```
┌────────────────────────────────────────────────────────────┐
│                 Alloy (Data Collector)                     │
│       Collects Metrics, Logs & Traces from Kubernetes      │
└─────────────────────────────┬──────────────────────────────┘
                              |
                              |
                              |
┌──────────────────────── LGTM Stack ────────────────────────┐
│                                                            │
│          ┌─────────────────────────────────────────┐       │
│          │             Grafana (G)                 │       │
│          │        (Visualization Layer)            │       │
│          └─────────┬─────────┬─────────┬───────────┘       │
│                    │         │         │                   │
│        ┌───────────┴──┐ ┌────┴────┐ ┌──┴──────────────┐    │
│        │   Loki (L)   │ │Mimir (M)│ │    Tempo (T)    │    │
│        │   (Logs)     │ │(Metrics)│ │   (Traces)      │    │
│        └──────┬───────┘ └────┬────┘ └──┬──────────────┘    │
│               │              │         │                   │
└───────────────┼──────────────┼─────────┼───────────────────┘
                │              │         │
                └──────────┐   │  ┌──────┘
                           │   │  │
            ┌──────────────┴───┴──┴───────┐
            │     Minio (S3 Storage)      │
            └─────────────────────────────┘
```

## 🎯 Features

- **Complete Observability**: Full metrics, logs, and traces collection and storage
- **Cross-Platform Support**:
  - **Bash scripts**: Linux, macOS, WSL
  - **PowerShell 7+ scripts**: Windows, Linux, macOS (identical functionality)
  - **Docker Desktop Compatible**: Auto-detects and handles mount propagation issues
- **Environment Adaptive**: Auto-detects Docker Desktop vs standard Kubernetes for optimal node-exporter deployment
- **Resource Optimized**: LAB/TESTING configurations with production guidance in comments
- **Single Node Ready**: Optimized for Minikube, Kind, Docker Desktop environments
- **Integrated Storage**: Uses Minio as unified S3-compatible storage backend
- **Unified Collection**: Alloy collects all telemetry data from Kubernetes clusters
- **Pre-configured**: Grafana comes with all datasources and custom Kubernetes dashboards
- **Working Dashboards**: Fixed Kubernetes monitoring with correct metric queries
- **Kubernetes Native**: Automatic discovery and monitoring of cluster components
- **Easy Deployment**: One-script installation with proper dependency ordering
- **Production Ready**: Extensive production guidance in configuration comments

## 📋 Prerequisites

### Core Requirements
- **Kubernetes Cluster**: Minikube, Kind, Docker Desktop K8s, or similar
- **kubectl**: Kubernetes command-line tool
- **Helm 3.x OR Docker**: Package manager for Kubernetes OR Docker for containerized Helm

### 🐳 Docker Desktop Users

**Important Setup Requirements:**
- Ensure **Docker Desktop is running**
- Enable **Kubernetes** in Docker Desktop settings:
  - Go to Docker Desktop → Settings → Kubernetes
  - Check "Enable Kubernetes"
  - Click "Apply & Restart"
- Verify single-node cluster is running: `kubectl get nodes`

### 🔧 Kubeconfig Configuration

The scripts automatically detect your kubeconfig in this order:
1. **KUBECONFIG environment variable** (if set)
2. **~/.kube/config** (default location)
3. **Windows**: `%USERPROFILE%\.kube\config` (PowerShell fallback)

**Custom kubeconfig path:**
```bash
# Linux/macOS/WSL
export KUBECONFIG=/path/to/your/kubeconfig
./scripts/install.sh

# PowerShell (any platform)
$env:KUBECONFIG = "/path/to/your/kubeconfig"
./scripts/install.ps1
```

### Platform-Specific Requirements

**Linux/macOS**:
- Bash shell (built-in)
- All scripts work natively

**Windows**:
- **PowerShell 7.0+** (required for cross-platform compatibility)
- Download from: https://github.com/PowerShell/PowerShell/releases
- **Note**: Windows PowerShell 5.1 is NOT supported - use PowerShell 7+
- All scripts tested on PowerShell 7.5+ on both Windows and Linux

### 🔄 Flexible Helm Requirements

The installation script automatically detects your environment:

**Option 1: Local Helm** (Recommended)
- Install Helm 3.x locally on your machine
- Fastest execution and best compatibility

**Option 2: Containerized Helm** (No local install needed)
- Requires Docker installed and running
- Uses `alpine/helm:3.13.2` and `alpine/kubectl:1.34.1` container images
- Perfect for environments where you can't/don't want to install Helm locally
- Automatically downloads required container images
- **CI/GitHub Actions compatible** with automatic network detection

**The script will:**
1. Check for local Helm installation first
2. Fall back to Docker + containerized Helm if Helm not found
3. Exit with helpful instructions if neither is available

### Minimum Resource Requirements

- **CPU**: 4 cores recommended (2 cores minimum)
- **Memory**: 6GB RAM recommended (4GB minimum)
- **Storage**: 15GB available disk space

### ✅ Environment Verification

Before installation, verify your environment is ready:

```bash
# Check Kubernetes cluster
kubectl cluster-info
kubectl get nodes

# Check Docker (if using containerized Helm)
docker info
docker run --rm hello-world

# Check Helm (if installed locally)
helm version

# Check available resources
kubectl top nodes 2>/dev/null || echo "Metrics server not available (optional)"

# Verify storage class
kubectl get storageclass
```

**Expected output examples:**
- Kubernetes cluster should show "running" status
- At least one node should be "Ready"
- Docker should show server version and no errors
- Default storage class should be available

## 🚀 Quick Start

### 1. Clone and Navigate

```bash
git clone https://github.com/devops-thiago/cloud-native-lgtm-stack
cd cloud-native-lgtm-stack
```

### 2. Install the Stack

**Linux/macOS/WSL (Bash):**
```bash
cd scripts
./install.sh
```

**Windows/Linux/macOS (PowerShell 7+):**
```powershell
cd scripts
./install.ps1        # Linux/macOS
.\install.ps1       # Windows
```

**Note**: PowerShell scripts work on all platforms with PowerShell 7+

### 3. Access Applications

**Grafana Dashboard:**
- URL: http://localhost:32000 (NodePort) or use port-forward
- Username: `admin`
- Password: `admin123`
- **Custom Dashboards Available:**
  - Kubernetes Cluster Overview - Resource utilization and node metrics
  - Kubernetes Pod Resources - Pod requests, limits, and management
  - Container Usage - Real-time CPU and memory usage from cAdvisor
  - Loki Dashboard - Log aggregation and search
  - Tempo Dashboard - Distributed tracing visualization
  - Node Exporter Dashboard - System-level metrics

**Minio Console:**
- Use port-forward: `kubectl port-forward svc/ltgm-minio-console 9001:9001`
- URL: http://localhost:9001
- Username: `admin`
- Password: `password123`

## 📊 Resource Usage

Each component is configured with minimal resource requests suitable for development:

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Minio     | 100m        | 128Mi          | 500m      | 512Mi        |
| Loki      | 100m        | 256Mi          | 500m      | 512Mi        |
| Tempo     | 100m        | 256Mi          | 500m      | 512Mi        |
| Mimir     | 200m        | 512Mi          | 1000m     | 1Gi          |
| Alloy     | 100m        | 256Mi          | 500m      | 512Mi        |
| Grafana   | 100m        | 256Mi          | 500m      | 512Mi        |
| Kube-state-metrics | 50m | 128Mi         | 200m      | 256Mi        |
| Node-exporter | 50m      | 128Mi          | 200m      | 256Mi        |
| **Total** | **800m**    | **1920Mi**     | **3900m** | **4096Mi**   |

## 🔧 Configuration

### Environment Variables

You can customize the deployment using environment variables:

- **NAMESPACE**: Target Kubernetes namespace (default: `default`)
- **RELEASE_PREFIX**: Prefix for all Helm releases (default: `ltgm`)
- **HELM_TIMEOUT**: Timeout for Helm install/upgrade operations (default: `10m`)

**Linux/macOS/WSL (Bash):**
```bash
export NAMESPACE=observability    # Default: default
export RELEASE_PREFIX=my-ltgm     # Default: ltgm
export HELM_TIMEOUT=15m           # Default: 10m
./scripts/install.sh
```

**Any Platform (PowerShell 7+):**
```powershell
$env:NAMESPACE = "observability"    # Default: default
$env:RELEASE_PREFIX = "my-ltgm"     # Default: ltgm
$env:HELM_TIMEOUT = "15m"           # Default: 10m
./install.ps1        # Linux/macOS
.\install.ps1       # Windows
```

### Custom Values

Each component can be customized by editing the values files in the `values/` directory:

- `values/minio-values.yaml` - Minio S3 storage configuration
- `values/loki-distributed-values.yaml` - Loki log aggregation configuration
- `values/tempo-distributed-values.yaml` - Tempo distributed tracing configuration
- `values/mimir-distributed-values.yaml` - Mimir metrics storage configuration
- `values/alloy-values.yaml` - Alloy data collector configuration
- `values/grafana-values.yaml` - Grafana visualization configuration
- `values/kube-state-metrics-values.yaml` - Kubernetes state metrics configuration
- `values/kubernetes-dashboards-configmap.yaml` - Custom Kubernetes dashboards
- `values/node-exporter-values.yaml` - Node-exporter for standard Kubernetes (Helm)
- `values/node-exporter-docker-desktop-daemonset.yaml` - Node-exporter for Docker Desktop

### Node-Exporter Deployment Options

The installation script automatically detects your Kubernetes environment:

**Docker Desktop**: Uses custom DaemonSet (`node-exporter-docker-desktop-daemonset.yaml`)
- Removes mount propagation settings that cause issues on Docker Desktop
- Disables problematic collectors (hwmon, thermal_zone, powersupply)
- Required for proper node metrics collection on Docker Desktop

**Standard Kubernetes**: Uses Helm chart (`node-exporter-values.yaml`)
- Full mount propagation support for complete system metrics
- All collectors enabled for comprehensive monitoring
- Suitable for cloud providers, bare metal, and standard K8s distributions

**Manual Override**:
```bash
# Force Docker Desktop mode
kubectl apply -f values/node-exporter-docker-desktop-daemonset.yaml

# Force Helm chart mode
helm install ltgm-node-exporter prometheus-community/prometheus-node-exporter \
  -f values/node-exporter-values.yaml
```

### 🐳 Containerized Helm Usage

If you need to run Helm commands manually without local installation:

**Linux/macOS/WSL (Bash):**
```bash
./scripts/helm-container.sh version
./scripts/helm-container.sh --test-connection
./scripts/helm-container.sh --kubectl get nodes
```

**Any Platform (PowerShell 7+):**
```powershell
./scripts/helm-container.ps1 version
./scripts/helm-container.ps1 --test-connection
./scripts/helm-container.ps1 --kubectl get nodes
```

**Benefits:**
- No local Helm installation required
- Consistent Helm version across environments
- Automatic environment detection (local/CI)
- Smart TTY handling for CI environments

## 🔧 Manual Installation (Component by Component)

If you prefer to install components manually or customize the installation order:

### Prerequisites for Manual Installation

```bash
# Add required Helm repositories
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add minio https://charts.min.io/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace observability
```

### 1. Install Minio (Storage Backend)

**Local Helm:**
```bash
helm upgrade --install ltgm-minio minio/minio \
  --namespace observability \
  --values values/minio-values.yaml \
  --wait --timeout=10m
```

**Containerized Helm:**
```bash
# Bash/Linux/macOS
./scripts/helm-container.sh upgrade --install ltgm-minio minio/minio \
  --namespace observability \
  --values values/minio-values.yaml \
  --wait --timeout=10m

# PowerShell (any platform)
./scripts/helm-container.ps1 upgrade --install ltgm-minio minio/minio \
  --namespace observability \
  --values values/minio-values.yaml \
  --wait --timeout=10m
```

### 2. Install Loki (Log Aggregation)

```bash
# Wait for Minio to be ready first
kubectl wait -n observability --for=condition=ready pod -l "release=ltgm-minio" --timeout=300s

# Local Helm
helm upgrade --install ltgm-loki grafana/loki-distributed \
  --namespace observability \
  --values values/loki-distributed-values.yaml \
  --wait --timeout=10m

# Containerized Helm (choose your platform)
./scripts/helm-container.sh upgrade --install ltgm-loki grafana/loki-distributed \
  --namespace observability --values values/loki-distributed-values.yaml --wait --timeout=10m
```

### 3. Install Tempo (Distributed Tracing)

```bash
# Local Helm
helm upgrade --install ltgm-tempo grafana/tempo-distributed \
  --namespace observability \
  --values values/tempo-distributed-values.yaml \
  --wait --timeout=10m

# Containerized Helm
./scripts/helm-container.sh upgrade --install ltgm-tempo grafana/tempo-distributed \
  --namespace observability --values values/tempo-distributed-values.yaml --wait --timeout=10m
```

### 4. Install Mimir (Metrics Storage)

```bash
# Local Helm
helm upgrade --install ltgm-mimir grafana/mimir-distributed \
  --namespace observability \
  --values values/mimir-distributed-values.yaml \
  --wait --timeout=10m

# Containerized Helm
./scripts/helm-container.sh upgrade --install ltgm-mimir grafana/mimir-distributed \
  --namespace observability --values values/mimir-distributed-values.yaml --wait --timeout=10m
```

### 5. Install Grafana (Visualization)

```bash
# Local Helm
helm upgrade --install ltgm-grafana grafana/grafana \
  --namespace observability \
  --values values/grafana-values.yaml \
  --wait --timeout=10m

# Containerized Helm
./scripts/helm-container.sh upgrade --install ltgm-grafana grafana/grafana \
  --namespace default --values values/grafana-values.yaml --wait --timeout=10m
```

### 6. Deploy Custom Dashboards

```bash
kubectl apply -f values/kubernetes-dashboards-configmap.yaml -n observability
```

### 7. Install Alloy (Data Collector)

```bash
# Local Helm
helm upgrade --install ltgm-alloy grafana/alloy \
  --namespace observability \
  --values values/alloy-values.yaml \
  --wait --timeout=10m

# Containerized Helm
./scripts/helm-container.sh upgrade --install ltgm-alloy grafana/alloy \
  --namespace observability --values values/alloy-values.yaml --wait --timeout=10m
```

### 8. Install Kube-state-metrics

```bash
# Local Helm
helm upgrade --install ltgm-kube-state-metrics prometheus-community/kube-state-metrics \
  --namespace observability \
  --values values/kube-state-metrics-values.yaml \
  --wait --timeout=10m

# Containerized Helm
./scripts/helm-container.sh upgrade --install ltgm-kube-state-metrics prometheus-community/kube-state-metrics \
  --namespace observability --values values/kube-state-metrics-values.yaml --wait --timeout=10m
```

### 9. Install Node-exporter

**Option A: Docker Desktop (Custom DaemonSet)**
```bash
kubectl apply -f values/node-exporter-docker-desktop-daemonset.yaml -n observability
```

**Option B: Standard Kubernetes (Helm Chart)**
```bash
# Local Helm
helm upgrade --install ltgm-node-exporter prometheus-community/prometheus-node-exporter \
  --namespace observability \
  --values values/node-exporter-values.yaml \
  --wait --timeout=10m

# Containerized Helm
./scripts/helm-container.sh upgrade --install ltgm-node-exporter prometheus-community/prometheus-node-exporter \
  --namespace observability --values values/node-exporter-values.yaml --wait --timeout=10m
```

### Verification Commands

```bash
# Check all deployments
kubectl get pods -n observability
helm list -n observability

# Access Grafana
kubectl port-forward svc/ltgm-grafana 3000:80 -n default
# Open http://localhost:3000 (admin/admin123)

# Access Minio Console
kubectl port-forward svc/ltgm-minio-console 9001:9001 -n default
# Open http://localhost:9001 (admin/password123)
```

**Note**: The automated scripts handle dependency ordering and retries. Manual installation requires careful attention to component startup order.

## 🛠️ Usage Examples

### Sending Logs to Loki

Using Promtail (or any log shipper):

```yaml
clients:
  - url: http://ltgm-loki-loki-distributed-gateway.default.svc.cluster.local:80/loki/api/v1/push
```

### Sending Traces to Tempo

Using OpenTelemetry:

```yaml
exporters:
  otlp:
    endpoint: http://ltgm-tempo-distributor.default.svc.cluster.local:4317
    tls:
      insecure: true
```

Using Jaeger:

```yaml
jaeger:
  collector:
    endpoint: http://ltgm-tempo-distributor.default.svc.cluster.local:14268/api/traces
```

**Note**: Service names follow the pattern `{release-prefix}-{component}-{service-type}`. Adjust according to your `RELEASE_PREFIX` (default: `ltgm`).

### Querying in Grafana

1. **Metrics (Mimir)**: Use PromQL queries like `rate(container_cpu_usage_seconds_total[5m])`
2. **Logs (Loki)**: Use LogQL queries like `{job="my-app"} |= "error"`
3. **Traces (Tempo)**: Search by TraceID, service name, or duration
4. **Correlation**: Click from logs to traces using TraceID correlation

### Automatic Data Collection

Alloy automatically collects:
- **Kubernetes Metrics**: Node, pod, container metrics from cAdvisor and kubelet
- **Cluster State**: Pod, service, deployment state from kube-state-metrics
- **System Metrics**: CPU, memory, disk, network from node-exporter
- **Application Metrics**: From pods with `prometheus.io/scrape: "true"` annotation
- **System Logs**: From all Kubernetes pods and containers
- **Traces**: Via OTLP endpoints (4317/4318)

## 🔍 Troubleshooting

### Common Issues

**Pods not starting:**
```bash
kubectl get pods -n default
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default
```

**Storage issues:**
```bash
kubectl get pvc -n default
kubectl get storageclass
```

**Network connectivity:**
```bash
kubectl get svc -n default
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n default
```

### Resource Constraints

If you encounter resource issues:

1. **Increase resource limits** in values files
2. **Add more memory/CPU** to your Kubernetes cluster
3. **Disable unused features** in component configurations

### Storage Issues

Minio buckets should be created automatically. If not:

```bash
kubectl port-forward svc/ltgm-minio-console 9001:9001 -n default
# Access http://localhost:9001 and create buckets: loki, tempo
```

### Dashboard Issues

If Kubernetes dashboards show no data:

1. **Check metrics collection**:
   ```bash
   kubectl logs -l app.kubernetes.io/name=alloy -n default
   kubectl get pods -l app.kubernetes.io/name=kube-state-metrics -n default
   kubectl get pods -l app.kubernetes.io/name=node-exporter -n default
   ```

2. **Verify dashboards loaded**:
   ```bash
   kubectl logs -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard -n default
   ```

3. **Check metric availability in Grafana**:
   - Go to Explore → Mimir datasource
   - Try queries like: `kube_pod_info`, `container_cpu_usage_seconds_total`, `node_memory_MemTotal_bytes`

### Containerized Helm Issues

If you encounter problems with containerized Helm:

#### 1. TTY Issues in CI Environments

**Error**: "the input device is not a TTY"

**Solution**: The scripts automatically detect CI environments (GitHub Actions, etc.) and disable TTY flags. If this fails:

```bash
# Force CI mode manually
CI=true ./scripts/install.sh
# or
CI=true ./scripts/helm-container.sh --test-connection
```

#### 2. Network Connectivity Issues

**Error**: "Cannot connect to Kubernetes cluster"

**Solutions**:

- **KinD/Local clusters**: Scripts automatically use `--network=host` in CI
- **Docker Desktop**: Scripts use `--add-host kubernetes.docker.internal:host-gateway`
- **Custom kubeconfig**: Ensure `KUBECONFIG` environment variable is set

```bash
# Test network connectivity
docker run --rm --network=host alpine/kubectl:1.34.1 version --client

# Verify kubeconfig mounting
ls -la ~/.kube/config
echo $KUBECONFIG
```

#### 3. Container Image Issues

**Error**: Image pull failures or kubectl connectivity issues

**Solution**: Update to latest images and verify connectivity:

```bash
# Pre-pull correct images
docker pull alpine/helm:3.13.2
docker pull alpine/kubectl:1.34.1

# Test images work
docker run --rm alpine/helm:3.13.2 version --client
docker run --rm alpine/kubectl:1.34.1 version --client
```

#### 4. General Containerized Helm Troubleshooting

1. **Check Docker status**:
   ```bash
   docker info
   docker images | grep -E "(helm|kubectl)"
   ```

2. **Test containerized Helm directly**:

   **Linux/macOS/WSL (Bash):**
   ```bash
   ./scripts/helm-container.sh --test-connection
   ./scripts/helm-container.sh version
   ```

   **Any Platform (PowerShell 7+):**
   ```powershell
   ./scripts/helm-container.ps1 --test-connection  # Linux/macOS
   .\scripts\helm-container.ps1 --test-connection  # Windows
   ./scripts/helm-container.ps1 version
   ```

3. **Check kubeconfig access**:

   **Linux/macOS/WSL (Bash):**
   ```bash
   ./scripts/helm-container.sh --kubectl cluster-info
   ./scripts/helm-container.sh --kubectl get nodes
   ```

   **Any Platform (PowerShell 7+):**
   ```powershell
   ./scripts/helm-container.ps1 --kubectl cluster-info   # Linux/macOS
   .\scripts\helm-container.ps1 --kubectl get nodes      # Windows
   ```

4. **Debug container execution**:
   ```bash
   # Check if containers can access the cluster
   docker run --rm -v ~/.kube/config:/tmp/kubeconfig:ro \
     -e KUBECONFIG=/tmp/kubeconfig --network=host \
     alpine/kubectl:1.34.1 cluster-info
   ```

#### 5. Environment-Specific Solutions

**GitHub Actions/CI:**
- Containers automatically use `--network=host`
- TTY flags are automatically removed
- Host networking allows access to KinD clusters

**Docker Desktop:**
- Uses `--add-host kubernetes.docker.internal:host-gateway`
- Works with Docker Desktop's built-in Kubernetes

**Custom Environments:**
```bash
# Override network detection
CI=true ./scripts/install.sh    # Force CI mode (host networking)
# or
CI=false ./scripts/install.sh   # Force local mode (Docker Desktop networking)
```

## 📁 Project Structure

```
cloud-native-lgtm-stack/
├── README.md
├── values/
│   ├── minio-values.yaml                           # Minio S3 storage
│   ├── loki-distributed-values.yaml                # Loki log aggregation
│   ├── tempo-distributed-values.yaml               # Tempo distributed tracing
│   ├── mimir-distributed-values.yaml               # Mimir metrics storage
│   ├── alloy-values.yaml                           # Alloy data collector
│   ├── grafana-values.yaml                         # Grafana visualization
│   ├── kube-state-metrics-values.yaml              # Kubernetes state metrics
│   ├── kubernetes-dashboards-configmap.yaml        # Custom K8s dashboards
│   ├── node-exporter-values.yaml                   # Node-exporter (Helm chart)
│   └── node-exporter-docker-desktop-daemonset.yaml # Node-exporter (Docker Desktop)
├── scripts/
│   ├── install.sh                                  # Bash: Linux/macOS/WSL installation
│   ├── install.ps1                                 # PowerShell 7+: Cross-platform installation
│   ├── uninstall.sh                               # Bash: Complete cleanup
│   ├── uninstall.ps1                              # PowerShell 7+: Cross-platform cleanup
│   ├── helm-container.sh                          # Bash: Containerized Helm wrapper
│   ├── helm-container.ps1                         # PowerShell 7+: Cross-platform Helm wrapper
│   ├── helm-utils.sh                              # Bash: Helm detection utilities
│   └── helm-utils.ps1                             # PowerShell 7+: Cross-platform Helm utilities
└── docs/                                           # Additional documentation
```

## 🗑️ Cleanup

To completely remove the stack:

**Linux/macOS/WSL (Bash):**
```bash
cd scripts
./uninstall.sh
```

**Any Platform (PowerShell 7+):**
```powershell
cd scripts
./uninstall.ps1        # Linux/macOS
.\uninstall.ps1       # Windows
```

This will:
1. Uninstall all Helm releases
2. Optionally remove persistent volume claims
3. Optionally remove the namespace

## 🔒 Production Deployment Guide

This stack is configured for **LAB/TESTING environments**. Each configuration file contains detailed production guidance in comments.

**Key Production Changes:**
```yaml
replicas: 1                     # PRODUCTION: Use 2+ for HA
admin_password: "admin123"       # PRODUCTION: Use strong passwords
insecure_skip_verify = true      # PRODUCTION: Enable TLS verification
```

### 🚀 Production Checklist

**Security**: Change default passwords, enable TLS, use proper authentication
**High Availability**: Scale replicas, enable persistence, use distributed storage
**Monitoring**: Configure alerting, set retention policies, optimize resources
**Network**: Use Ingress with TLS, configure load balancers, enable DNS

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with Minikube
5. Submit a pull request

## 📚 Additional Resources

- [Loki Documentation](https://grafana.com/docs/loki/)
- [Tempo Documentation](https://grafana.com/docs/tempo/)
- [Grafana Documentation](https://grafana.com/docs/grafana/)
- [Minio Documentation](https://min.io/docs/)
- [Helm Charts Documentation](https://helm.sh/docs/chart_template_guide/)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review component logs using kubectl
3. Open an issue in this repository

---

**Happy Observing! 📊🔍**
