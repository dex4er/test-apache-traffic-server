#!/usr/bin/env bash
set -euo pipefail

config="$(dirname "$0")/kind-cluster.yaml"
name=$(yq .name "${config}")

if [[ -z ${name} ]]; then
  echo "Cluster name not found in config"
  exit 1
fi

source=$(git config --get remote.origin.url || true)
branch=$(git branch --show-current || true)
sha1=$(git rev-parse HEAD)
if [[ -n ${branch} ]]; then
  revision="${branch}@sha1:${sha1}"
else
  revision="local"
fi

./flux.sh push artifact "oci://localhost:5001/flux-${name}:latest" \
  --path="./manifest" \
  --source="${source:-local}" \
  --revision="${revision:-unknown}"
