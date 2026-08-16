SHELL := /usr/bin/env bash

.PHONY: bootstrap-secret seed-vault-secrets bootstrap-argocd status

ENV_FILE ?= .env

define with_env
set -euo pipefail; \
if [[ -f "$(ENV_FILE)" ]]; then set -a; source "$(ENV_FILE)"; set +a; fi; \
if [[ -z "$${KUBECONFIG:-}" && -f "../terraform-homelab/configs/kubeconfig" ]]; then export KUBECONFIG="../terraform-homelab/configs/kubeconfig"; fi; \
$1
endef

# Passo 0, uma unica vez: secret que o Vault (backend Postgres) precisa pra subir.
bootstrap-secret:
	@$(call with_env,./scripts/ensure-vault-postgres-secret.sh)

# Popula o Vault com os secrets de aplicacao (mesma logica do helmfile antigo).
seed-vault-secrets:
	@$(call with_env,./scripts/seed-vault-secrets.sh)

# Passo 0 do proprio Argo CD: precisa existir ANTES do GitOps poder se autogerenciar.
# So roda uma vez por cluster novo - depois disso o app "argo-cd" (apps/06-development)
# assume o gerenciamento de si mesmo. O release name aqui ("argo-cd") tem que
# bater com helm.releaseName em apps/06-development/argo-cd.yaml, senao essa
# Application cria um SEGUNDO Argo CD em vez de assumir este.
bootstrap-argocd:
	@$(call with_env, \
	  kubectl create namespace development --dry-run=client -o yaml | kubectl apply -f -; \
	  helm upgrade --install argo-cd argo-cd \
	    --repo https://argoproj.github.io/argo-helm \
	    --version 9.5.14 \
	    --namespace development \
	    --values values/development/argo-cd.yaml; \
	  kubectl apply -f bootstrap/project.yaml; \
	  kubectl apply -f bootstrap/root.yaml \
	)

status:
	kubectl get applications -n development
	kubectl get nodes
