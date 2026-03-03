#!/usr/bin/env bash
set -euo errexit -o pipefail

config="$(dirname "$0")/kind-cluster.yaml"
name=$(yq .name "${config}")

if ! helm plugin list | grep -qs ^diff; then
  helm plugin install https://github.com/databus23/helm-diff --verify=false
fi

if [[ -z ${name} ]]; then
  echo "Cluster name not found in config"
  exit 1
fi

if [[ -d "${HOME}/.kube/kind" ]]; then
  kubeconfig="${HOME}/.kube/kind/${name}"
else
  kubeconfig="${HOME}/.kube/config"
fi

diff_args=()
for arg in "$@"; do
  case "${arg}" in
  install)
    diff_args+=("upgrade" "--install")
    ;;
  --create-namespace)
    # skip
    ;;
  *)
    diff_args+=("${arg}")
    ;;
  esac
done

output=$(helm diff --kube-context "kind-${name}" --kubeconfig "${kubeconfig}" "${diff_args[@]}" --allow-unreleased)

if [[ -n ${output} ]]; then
  echo "*** Running 'helm $*' for $(basename "${PWD}")"
  helm --kube-context "kind-${name}" --kubeconfig "${kubeconfig}" "$@" --wait
else
  echo "*** No changes detected, skipping 'helm $*' for $(basename "${PWD}")"
fi
