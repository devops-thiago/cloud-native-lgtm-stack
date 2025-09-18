# E2E Testing for Cloud Native LGTM Stack

This directory contains end-to-end (e2e) tests for the Cloud Native LGTM stack installation and uninstallation scripts. The tests validate both shell and PowerShell scripts across different Helm deployment scenarios.

## Overview

The e2e tests validate:
- ✅ Shell scripts (`install.sh` / `uninstall.sh`) on Linux
- ✅ PowerShell scripts (`install.ps1` / `uninstall.ps1`) on Windows
- ✅ Local Helm installation scenario
- ✅ Containerized Helm scenario (Docker + Helm containers)
- ✅ Single-node Kubernetes cluster testing (using kind)
- ✅ Complete install → validate → uninstall → validate cycle

## GitHub Actions Workflows

### 1. Shell Scripts E2E Tests (`.github/workflows/e2e-shell-scripts.yml`)
Tests shell scripts on Ubuntu with:
- **Job 1**: Local Helm installation
- **Job 2**: Containerized Helm (Docker + alpine/helm container)

### 2. PowerShell Scripts E2E Tests (`.github/workflows/e2e-powershell-scripts.yml`)
Tests PowerShell scripts on Windows with:
- **Job 1**: Local Helm installation
- **Job 2**: Containerized Helm (Docker + alpine/helm container)

### 3. Complete Cross-Platform Tests (`.github/workflows/e2e-complete.yml`)
Comprehensive matrix testing across:
- **OS**: Ubuntu (Linux) + Windows
- **Script Type**: Shell + PowerShell
- **Helm Mode**: Local + Containerized
- **Total**: 4 test combinations in a single workflow

## Test Scenarios

### Scenario 1: Local Helm
- Helm 3.13.2 installed locally
- Direct `helm` command execution
- Faster execution, standard approach

### Scenario 2: Containerized Helm
- Docker available, no local Helm
- Uses `alpine/helm:3.13.2` container
- Tests fallback mechanism for environments without Helm

## Test Flow

Each test follows this sequence:

1. **Setup**
   - Create single-node Kubernetes cluster (kind)
   - Install/configure required tools (kubectl, helm, docker)
   - Verify cluster connectivity

2. **Installation**
   - Run appropriate install script (`install.sh` or `install.ps1`)
   - Wait for pods to become ready
   - Validate Helm releases are created
   - Verify pods and services are running

3. **Uninstallation**
   - Run appropriate uninstall script (`uninstall.sh` or `uninstall.ps1`)
   - Verify Helm releases are removed
   - Confirm pods are terminated/removed

4. **Validation**
   - Comprehensive checks at each step
   - Error reporting and debugging info
   - Proper cleanup verification

## Utility Scripts

### `scripts/e2e-test-utils.sh` (Shell)
Utility functions for shell-based testing:
```bash
# Validate installation
./e2e-test-utils.sh validate-install

# Validate uninstallation  
./e2e-test-utils.sh validate-uninstall

# Run full test cycle
./e2e-test-utils.sh full-test

# Run with containerized Helm
./e2e-test-utils.sh full-test containerized-helm
```

### `scripts/e2e-test-utils.ps1` (PowerShell)
Utility functions for PowerShell-based testing:
```powershell
# Validate installation
.\e2e-test-utils.ps1 -Command validate-install

# Validate uninstallation
.\e2e-test-utils.ps1 -Command validate-uninstall

# Run full test cycle
.\e2e-test-utils.ps1 -Command full-test

# Run with containerized Helm
.\e2e-test-utils.ps1 -Command full-test -Mode containerized-helm
```

## Environment Variables

- `NAMESPACE` - Kubernetes namespace for testing (default: `lgtm-test`)
- `RELEASE_PREFIX` - Helm release prefix (default: `test`)

## Local Testing

### Prerequisites
- Docker installed and running
- kubectl installed
- kind installed
- For PowerShell tests: PowerShell Core 7+

### Running Tests Locally

1. **Create test cluster**:
   ```bash
   kind create cluster --name lgtm-test
   ```

2. **Run shell tests**:
   ```bash
   cd scripts
   export NAMESPACE=lgtm-test
   export RELEASE_PREFIX=test
   ./e2e-test-utils.sh full-test
   ```

3. **Run PowerShell tests** (Windows):
   ```powershell
   cd scripts
   $env:NAMESPACE = "lgtm-test"
   $env:RELEASE_PREFIX = "test"
   .\e2e-test-utils.ps1 -Command full-test
   ```

4. **Cleanup**:
   ```bash
   kind delete cluster --name lgtm-test
   ```

## Workflow Triggers

The workflows are triggered by:
- **Push** to `main` or `develop` branches (when scripts or values change)
- **Pull Request** to `main` or `develop` branches (when scripts or values change)
- **Manual dispatch** via GitHub Actions UI

## Validation Checks

### Installation Validation
- ✅ Namespace creation
- ✅ Helm releases deployed (`minio`, `loki`, `tempo`, `mimir`, `alloy`, `grafana`, `kube-state-metrics`)
- ✅ Pods running and ready
- ✅ Services created
- ✅ No failed pods

### Uninstallation Validation
- ✅ Helm releases removed
- ✅ Pods terminated/removed
- ✅ Clean namespace state
- ✅ No hanging resources

## Troubleshooting

### Common Issues
1. **Timeout errors**: Increase timeout values in workflows
2. **Resource constraints**: Adjust resource limits or use smaller cluster
3. **Image pull failures**: Check network connectivity and image availability
4. **Permission errors**: Verify RBAC and service account permissions

### Debug Information
The workflows provide extensive debug output:
- Cluster information (`kubectl cluster-info`)
- Pod status and logs
- Service endpoints
- Helm release status
- Container logs for failed deployments

## Future Enhancements

- [ ] Add performance benchmarking
- [ ] Test with different Kubernetes versions
- [ ] Add integration tests with external services
- [ ] Test upgrade/rollback scenarios
- [ ] Add chaos engineering tests
- [ ] Multi-node cluster testing