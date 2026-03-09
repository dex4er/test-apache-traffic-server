# test-ats

Simple local setup for running a kind cluster, pushing Flux manifests to a local OCI registry, and reconciling them with Flux.

## Requirements

- Docker
- kind
- kubectl
- helm
- flux
- yq
- httpie (`http` command, used for testing and Via header decoding — install separately, e.g. `brew install httpie`)

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
http -v localhost:31080/podinfo-0 X-Debug:x-remap,x-cache | ./tools/decode-via.pl
```

This sends a request through ATS and decodes the `Via` response header into
human-readable cache/proxy transaction codes (see [Tools](#tools) below).

5. Delete cluster when done:

```bash
./kind-delete.sh
```

## Tools

### tools/decode-via.pl

Decodes the `Via` response header added by ATS into human-readable transaction
codes. ATS encodes cache lookup result, server connection info, proxy behaviour,
and error codes into a compact string — `decode-via.pl` expands each code into
a readable label such as `cache:hit-fresh` or `cache:miss`.

Requires `httpie` (`http` command) and Perl. Pipe any HTTP response through it:

```bash
# Single request with decoded Via header
http -v localhost:31080/podinfo-0 | ./tools/decode-via.pl

# Watch cache warm up over repeated requests
for i in $(seq 5); do http localhost:31080/podinfo-0 | ./tools/decode-via.pl | grep Via; done
```

The decoded `Via` line looks like:

```
Via: [uScMsSf pN eN:t cCp sS] cache:miss fill:written server:served
```

For the full encoding reference see the
[ATS FAQ — How do I interpret the Via header?](https://docs.trafficserver.apache.org/en/latest/appendices/faq.en.html#how-do-i-interpret-the-via-header)

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

## ATS — accessing the pod

Use `./kubectl.sh exec` to run commands inside the ATS pod:

```bash
./kubectl.sh exec -n ats apache-traffic-server-0 -- traffic_ctl config reload
./kubectl.sh exec -n ats apache-traffic-server-0 -- traffic_ctl config get proxy.config.http.cache.required_headers
./kubectl.sh exec -n ats apache-traffic-server-0 -- traffic_ctl metric get proxy.process.cache.volume_1.bytes
./kubectl.sh logs -n ats apache-traffic-server-0 -f
```

For an interactive shell:

```bash
./kubectl.sh exec -it -n ats apache-traffic-server-0 -- /bin/sh
```

## ATS — resetting the disk cache (PVC wipe)

The cache is stored on two PersistentVolumeClaims (`ats-cache-0-apache-traffic-server-0`
and `ats-cache-1-apache-traffic-server-0`). Reloading config or restarting the pod
does **not** clear them. To permanently wipe the cache:

```bash
./kubectl.sh delete pvc -n ats ats-cache-0-apache-traffic-server-0 ats-cache-1-apache-traffic-server-0
```

The StatefulSet will recreate empty PVCs when the pod is next scheduled, and ATS
will rebuild the cache directory structure from scratch on startup. If the pod is
already running, delete it to trigger rescheduling:

```bash
./kubectl.sh delete pod -n ats apache-traffic-server-0
```

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
