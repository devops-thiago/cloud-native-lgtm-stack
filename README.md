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
                └──────┬───────┼─────────┘
                       │       │
            ┌──────────┴───────┴──────────┐
            │     Minio (S3 Storage)      │
            └─────────────┬───────────────┘
                          │
┌─────────────────────────┴─────────────────────────────────┐
│                 Alloy (Data Collector)                    │
│       Collects Metrics, Logs & Traces from Kubernetes     │
└───────────────────────────────────────────────────────────┘
```

## 🎯 Features

- **Complete Observability**: Full metrics, logs, and traces collection and storage
- **Environment Adaptive**: Auto-detects Docker Desktop vs standard Kubernetes
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

- **Kubernetes Cluster**: Minikube, Kind, Docker Desktop K8s, or similar
- **kubectl**: Kubernetes command-line tool
- **Helm 3.x OR Docker**: Package manager for Kubernetes OR Docker for containerized Helm

### 🔄 Flexible Helm Requirements

The installation script automatically detects your environment:

**Option 1: Local Helm** (Recommended)
- Install Helm 3.x locally on your machine
- Fastest execution and best compatibility

**Option 2: Containerized Helm** (No local install needed)
- Requires Docker installed and running
- Uses `alpine/helm:3.13.2` container image
- Perfect for environments where you can't/don't want to install Helm locally
- Automatically downloads required container images

**The script will:**
1. Check for local Helm installation first
2. Fall back to Docker + containerized Helm if Helm not found
3. Exit with helpful instructions if neither is available

### Minimum Resource Requirements

- **CPU**: 4 cores recommended (2 cores minimum)
- **Memory**: 6GB RAM recommended (4GB minimum)
- **Storage**: 15GB available disk space

## 🚀 Quick Start

### 1. Clone and Navigate

```bash
git clone <repository-url>
cd cloud-native-ltgm-stack
```

### 2. Install the Stack

```bash
cd scripts
./install.sh
```

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

```bash
export NAMESPACE=observability    # Default: default
export RELEASE_PREFIX=my-ltgm     # Default: ltgm
./scripts/install.sh
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

```bash
# Use the containerized Helm wrapper
./scripts/helm-container.sh version
./scripts/helm-container.sh repo list
./scripts/helm-container.sh list -A

# Test cluster connectivity
./scripts/helm-container.sh --test-connection

# Pre-pull container images
./scripts/helm-container.sh --pull-images

# Run kubectl in container
./scripts/helm-container.sh --kubectl get nodes
```

**Benefits of Containerized Helm:**
- No need to install Helm locally
- Consistent Helm version across environments
- Isolated execution environment
- Automatically mounts kubeconfig and project files
- Works on any system with Docker installed

## 🛠️ Usage Examples

### Sending Logs to Loki

Using Promtail (or any log shipper):

```yaml
clients:
  - url: http://loki.default.svc.cluster.local:3100/loki/api/v1/push
```

### Sending Traces to Tempo

Using OpenTelemetry:

```yaml
exporters:
  otlp:
    endpoint: http://tempo.default.svc.cluster.local:4317
    tls:
      insecure: true
```

Using Jaeger:

```yaml
jaeger:
  collector:
    endpoint: http://tempo.default.svc.cluster.local:14268/api/traces
```

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

3. **Update dashboards**:
   ```bash
   cd scripts
   ./update-grafana-dashboards.sh
   ```

4. **Check metric availability in Grafana**:
   - Go to Explore → Mimir datasource
   - Try queries like: `kube_pod_info`, `container_cpu_usage_seconds_total`, `node_memory_MemTotal_bytes`

### Containerized Helm Issues

If you encounter problems with containerized Helm:

1. **Check Docker status**:
   ```bash
   docker info
   docker images | grep helm
   ```

2. **Test containerized Helm directly**:
   ```bash
   ./scripts/helm-container.sh --test-connection
   ./scripts/helm-container.sh version
   ```

3. **Pre-pull images manually**:
   ```bash
   docker pull alpine/helm:3.13.2
   docker pull bitnami/kubectl:latest
   ```

4. **Check kubeconfig access**:
   ```bash
   ./scripts/helm-container.sh --kubectl cluster-info
   ```

## 📁 Project Structure

```
cloud-native-ltgm-stack/
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
│   ├── install.sh                                  # Smart installation (local/containerized Helm)
│   ├── uninstall.sh                               # Complete cleanup
│   ├── update-grafana-dashboards.sh               # Dashboard updates
│   ├── helm-container.sh                          # Containerized Helm wrapper
│   └── helm-utils.sh                              # Helm detection utilities
└── docs/                                           # Additional documentation
```

## 🗑️ Cleanup

To completely remove the stack:

```bash
cd scripts
./uninstall.sh
```

This will:
1. Uninstall all Helm releases
2. Optionally remove persistent volume claims  
3. Optionally remove the namespace

## 🔒 Production Deployment Guide

This stack is configured for **LAB/TESTING environments** with extensive production guidance in configuration comments.

### 📝 Configuration Files Comments

Each `.yaml` file contains detailed comments with:
- **LAB/TESTING**: Current settings explanation
- **PRODUCTION**: Recommended changes for production use
- **Security considerations** for each component
- **Resource scaling guidance** based on workload

Look for comments like:
```yaml
replicas: 1                     # PRODUCTION: Consider 2+ for HA with proper storage
admin_password: "admin123"       # PRODUCTION: Use strong password + secrets
insecure_skip_verify = true      // PRODUCTION: Use proper TLS verification
```

### 🚀 Production Checklist

**Security & Authentication**:
- [ ] Change all default passwords (Grafana, Minio)
- [ ] Enable TLS/SSL for all component communications  
- [ ] Configure proper authentication (LDAP/OAuth for Grafana)
- [ ] Use Kubernetes secrets instead of plain text passwords
- [ ] Enable proper TLS certificate verification
- [ ] Configure network policies for component isolation

**High Availability & Storage**:
- [ ] Enable persistence for Grafana dashboards/settings
- [ ] Configure distributed mode for Minio (multiple instances)
- [ ] Scale replica counts for critical components (2+)
- [ ] Use high-performance storage classes for data persistence
- [ ] Configure resource quotas and limits appropriately

**Monitoring & Observability**:
- [ ] Enable ServiceMonitor for Prometheus scraping
- [ ] Configure proper resource requests/limits based on usage
- [ ] Set up alerting rules and notification channels
- [ ] Configure log retention policies
- [ ] Enable trace sampling for high-traffic applications

**Network & Access**:
- [ ] Replace NodePort services with Ingress + TLS
- [ ] Configure proper load balancers for external access
- [ ] Set up DNS names instead of IP addresses
- [ ] Enable ingress controllers with SSL termination

**Node-Exporter Specific**:
- [ ] Review security contexts and user permissions
- [ ] Configure node selectors for worker-only deployment
- [ ] Enable Pod Security Policies if required
- [ ] Review host volume mount security implications

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
