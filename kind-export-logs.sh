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
  test -d "${kubeconfig}" && exit 1
  rm -f "${kubeconfig}"
else
  kubeconfig="${HOME}/.kube/config"
fi

output_dir="${1:-$(dirname "$0")/logs}"

rm -rf "${output_dir}/docker-info.txt" "${output_dir}/kind-version.txt" "${output_dir}/${name}-control-plane"

kind export logs --name "${name}" "${output_dir}"
