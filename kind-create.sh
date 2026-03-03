#!/usr/bin/env bash
set -euo errexit -o pipefail

config="$(dirname "$0")/kind-cluster.yaml"
name=$(yq .name "${config}")

if [[ -z ${name} ]]; then
  echo "Cluster name not found in config"
  exit 1
fi

if [[ -d "${HOME}/.kube/kind" ]]; then
  kubeconfig="${HOME}/.kube/kind/${name}"
else
  kubeconfig="${HOME}/.kube/config"
fi

kind create cluster --config kind-cluster.yaml --name "${name}" --kubeconfig "${kubeconfig}"

reg_name='kind-registry'
reg_port='5001'
if [[ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
    registry:2
fi

registry_dir="/etc/containerd/certs.d/localhost:${reg_port}"
for node in $(kind get nodes --name "${name}"); do
  docker exec "${node}" mkdir -p "${registry_dir}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${registry_dir}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
done

if [[ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" == 'null' ]]; then
  docker network connect "kind" "${reg_name}"
fi

lf=$'\n'

export clusterName="${name}"
export kindRegistry="${reg_name}:5000"
export localRegistry="localhost:${reg_port}"

./kubectl.sh create configmap local-registry-hosting \
  --namespace kube-public \
  --from-literal=localRegistryHosting.v1="host: ${localRegistry}${lf}help: https://kind.sigs.k8s.io/docs/user/local-registry/${lf}"

./kubectl.sh create namespace flux-system

./kubectl.sh create configmap cluster-vars \
  --namespace flux-system \
  --from-literal=clusterName="${clusterName}" \
  --from-literal=kindRegistry="${kindRegistry}" \
  --from-literal=localRegistry="${localRegistry}"

./helm.sh install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --version 0.43.0 \
  --namespace flux-system

./flux.sh envsubst --strict <fluxinstance.yaml | ./kubectl.sh apply --wait -f -
