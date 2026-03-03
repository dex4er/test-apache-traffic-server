#! /usr/bin/env bash

helm template \
  "$(yq .spec.releaseName helmrelease.yaml)" \
  "$(yq .spec.chart.spec.chart helmrelease.yaml)" \
  --repo "$(yq .spec.url helmrepository.yaml)" \
  --version "$(yq .spec.chart.spec.version helmrelease.yaml)" \
  --values values.yaml \
  "$@"
