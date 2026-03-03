# test-ats

Simple local setup for running a kind cluster, pushing Flux manifests to a local OCI registry, and reconciling them with Flux.

## Requirements

- Docker
- kind
- kubectl
- helm
- flux
- yq

## Install tools with mise-en-place

Install the tools defined in `mise.toml`:

```bash
mise install
```

Activate them in your current shell:

```bash
eval "$(mise activate zsh)"
```

`mise.toml` currently manages `flux2`, `helm`, `kind`, `kubectl`, and `yq`.

## Project layout

- `manifest/` - Kubernetes manifests pushed as a Flux OCI artifact:
	- `manifest/ats/` - Apache Traffic Server deployment and service, including ATS configuration files used by the container.
	- `manifest/podinfo/` - `podinfo` workload used as a simulated backend service.
	- `manifest/system/` - additional cluster/system-level Kubernetes services (currently includes `metrics-server`).
	- `manifest/namespaces/` - manifests that create required namespaces.
- `kind-create.sh` - creates kind cluster and local registry
- `kind-delete.sh` - deletes kind cluster
- `kind-export-logs.sh` - exports kind cluster diagnostics/logs to `./logs` (or to a custom output directory passed as first argument)
- `flux-push.sh` - pushes manifests from `manifest/` to local registry
- `fluxinstance.yaml` - FluxInstance definition used by `kind-create.sh` to bootstrap Flux controllers and configure sync from local `OCIRepository` artifact (`oci://${kindRegistry}/flux-${clusterName}:latest`)

## Quick start

1. Create cluster:

```bash
./kind-create.sh
```

This step also starts (or reuses) the local Docker registry container named `kind-registry` on `localhost:5001`.

2. Push manifests to local registry:

```bash
./flux-push.sh
```

3. Verify resources (optional):

```bash
./kubectl.sh get pods -A
./kubectl.sh get ocirepo,ks,helmrepo,hr -A
```

4. Verify app endpoint:

```bash
curl -i http://localhost:31080
```

5. Delete cluster when done:

```bash
./kind-delete.sh
```

## CLI wrappers

Use local wrappers instead of raw `flux`, `kubectl`, and `helm` commands:

- `./flux.sh`
- `./kubectl.sh`
- `./helm.sh`

These wrappers automatically set the correct kube context and kubeconfig for the test kind cluster (name from `kind-cluster.yaml`). This helps avoid accidentally running commands against a different Kubernetes cluster.

## Notes

- Cluster name is read from `kind-cluster.yaml`.
- `flux-push.sh` publishes to `oci://localhost:5001/flux-<cluster-name>:latest`.
- Flux sync is configured with `OCIRepository` (not Git).
- Port `31080` on `localhost` is mapped to kind node port `31080`.
- The `ats-service` Service uses `type: NodePort` with `nodePort: 31080`, so the app is reachable at `http://localhost:31080`.

## Troubleshooting

### 1) `flux-push.sh` fails to push artifact

- Check local registry container:

```bash
docker ps --filter name=kind-registry
```

- If missing, recreate environment:

```bash
./kind-delete.sh
./kind-create.sh
```

### 2) Flux cannot pull from local OCI registry

- Confirm `OCIRepository` status:

```bash
./kubectl.sh -n flux-system get ocirepository flux-system -o yaml
```

- Check source-controller logs:

```bash
./kubectl.sh -n flux-system logs deploy/source-controller --tail=200
```

### 3) Resources are not reconciling

- Trigger and inspect Flux reconciliation:

```bash
./flux.sh reconcile source oci flux-system -n flux-system
./flux.sh reconcile kustomization flux-system -n flux-system
./flux.sh get all -A
```

### 4) Cannot access cluster with wrappers

- Verify cluster name and kubeconfig path generated from `kind-cluster.yaml`.
- Recreate cluster if kubeconfig is stale:

```bash
./kind-delete.sh
./kind-create.sh
```
