#!/usr/bin/env bash
# Aponta o Avisa IA de um ambiente para o banco no cluster PostgreSQL
# (CloudNativePG): atualiza DATABASE_URL e POSTGRES_* no Vault (mount avisa-ia).
# A senha vem de k8s-homelab/postgresql/avisa_<env>. Depois de rodar, o VSO
# sincroniza o Secret em ~1 min; reiniciar o backend para ler o valor novo.
#
# Uso: scripts/avisa-db-vault-cutover.sh <dev|staging|prod>
set -euo pipefail

env="${1:?uso: $0 <dev|staging|prod>}"
case "${env}" in
  dev)     vault_path="avisa-ia-backend-development"; db="avisa_dev" ;;
  staging) vault_path="avisa-ia-backend-staging";     db="avisa_staging" ;;
  prod)    vault_path="avisa-ia-backend-production";  db="avisa_prod" ;;
  *) echo "ambiente invalido: ${env}" >&2; exit 1 ;;
esac

: "${VAULT_NAMESPACE:=secrets}"
: "${VAULT_POD:=hashicorp-vault-0}"
: "${VAULT_CREDENTIALS_FILE:=../scripts-k8s-homelab/vault/vault-credentials.txt}"
token="$(sed -n 's/^ROOT_TOKEN=//p' "${VAULT_CREDENTIALS_FILE}" | tail -n1)"
vault() { kubectl -n "${VAULT_NAMESPACE}" exec -i "${VAULT_POD}" -- env VAULT_TOKEN="${token}" vault "$@"; }

password="$(vault kv get -mount=k8s-homelab -field=password "postgresql/${db}")"
url="postgresql://${db}:${password}@postgresql-rw.postgresql.svc.cluster.local:5432/${db}"

vault kv patch -mount=avisa-ia "${vault_path}" \
  DATABASE_URL="${url}" \
  POSTGRES_DB="${db}" \
  POSTGRES_USER="${db}" \
  POSTGRES_PASSWORD="${password}" >/dev/null
echo "Vault avisa-ia/${vault_path} atualizado para o banco ${db}."
