#!/usr/bin/env bash
# Reverse of platform-apply.sh. Best-effort.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${HERE}/.." && pwd)"
DIST="${DIST:-k0s}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${ROOT}/.kube/${DIST}.config}"
export KUBECONFIG="${KUBECONFIG_PATH}"

kubectl delete -f "${ROOT}/platform/secrets/cluster-secret-store.example.yaml" --ignore-not-found
helmfile -f "${ROOT}/platform/helmfile.yaml" --selector layer=secrets destroy || true
helmfile -f "${ROOT}/platform/helmfile.yaml" --selector layer=multus  destroy || true
helmfile -f "${ROOT}/platform/helmfile.yaml" --selector "cni=${CNI:-calico}" destroy || true
kubectl delete -f "${ROOT}/platform/namespaces.yaml" --ignore-not-found || true
