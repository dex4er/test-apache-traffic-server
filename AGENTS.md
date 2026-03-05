# Agent Instructions

See [README.md](README.md) for full project documentation, including:

- architecture overview (ATS, podinfo, FluxCD, kind cluster)
- project layout
- quick start guide
- CLI wrappers (`./kubectl.sh`, `./flux.sh`, `./helm.sh`) — always use these
  instead of raw `kubectl`, `flux`, or `helm` to avoid running commands against
  the wrong cluster
- how to access the ATS pod and run commands inside it
- how to wipe the disk cache PVCs
- troubleshooting guide

## Key Rules for This Project

- Always use `./kubectl.sh` instead of `kubectl`.
- Always use `./flux.sh` instead of `flux`.
- Always use `./helm.sh` instead of `helm`.
- Push manifest changes with `./flux-push.sh` — do not apply manifests directly
  with kubectl apply.
- `traffic_ctl config defaults` inside the pod reports **currently loaded
  values**, not ATS compiled-in defaults. Consult the ATS documentation for true
  defaults:
  https://docs.trafficserver.apache.org/en/latest/admin-guide/files/records.yaml.en.html

## ATS Configuration Gotchas

- `cache.config`: `action=cache` is **invalid** and silently ignored. Use
  `ttl-in-cache=<seconds>` (integer only, not `60s` or `0:1:0`).
- `storage.config` / `volume.config`: each logical volume requires a **separate
  physical storage entry**. Splitting one directory into two logical volumes
  disables the cache entirely.
- `remap.config`: rules match **top-to-bottom, first match wins** — specific
  paths must appear before the catch-all `/`.

## Comment Style

- All comments are written in **English**.
- One comment block per **complete logical rule** (not per individual line).
- Always place a **blank line between a comment block and the code it describes**.
- In YAML (`records.yaml`): place the comment **above** the key it describes,
  indented to match the key.
- Comment content should include: what the setting/rule does, allowed values
  where relevant, the ATS default value, and the reason this project overrides
  it.
