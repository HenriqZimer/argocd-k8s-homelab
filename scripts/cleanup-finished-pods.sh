#!/usr/bin/env bash
# Remove pods que ja terminaram (Succeeded e Failed) de todos os namespaces.
#
# Uso:
#   scripts/cleanup-finished-pods.sh              # mostra o que seria removido (dry-run)
#   scripts/cleanup-finished-pods.sh --apply      # remove de verdade
#   scripts/cleanup-finished-pods.sh --apply -n security   # so um namespace
#
# So mexe em pods com phase Succeeded/Failed (Completed, Error, Terminated,
# Evicted...). Pods Running/Pending/CrashLoopBackOff nunca entram.
set -euo pipefail

apply=false
namespace=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) apply=true ;;
    -n|--namespace) namespace="${2:?faltou o namespace}"; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "argumento desconhecido: $1" >&2; exit 1 ;;
  esac
  shift
done

scope=(-A)
[[ -n "$namespace" ]] && scope=(-n "$namespace")

total=0
for phase in Succeeded Failed; do
  mapfile -t pods < <(kubectl get pods "${scope[@]}" --field-selector="status.phase=${phase}" \
    --no-headers -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name' 2>/dev/null)

  count=${#pods[@]}
  [[ $count -eq 0 ]] && { echo "${phase}: nenhum"; continue; }
  echo "${phase}: ${count}"

  for line in "${pods[@]}"; do
    read -r ns name <<<"$line"
    if $apply; then
      kubectl delete pod -n "$ns" "$name" --wait=false >/dev/null
      echo "  removido  $ns/$name"
    else
      echo "  removeria $ns/$name"
    fi
  done
  total=$((total + count))
done

if $apply; then
  echo "Total removido: ${total}"
else
  echo "Total que seria removido: ${total} (rode com --apply para remover)"
fi
