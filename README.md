# argocd-k8s-homelab

Stack do homelab Kubernetes gerenciada via **GitOps (Argo CD)**, em vez do
`helmfile` usado em [`helm-k8s-homelab`](../helm-k8s-homelab). Mesmos charts,
mesmas versoes, mesmos `values.yaml` (copiados 1:1) - o que muda e o motor de
sincronizacao: em vez de `make apply` rodar `helmfile apply` uma vez, o Argo CD
fica olhando este repositorio continuamente e reconcilia o cluster sozinho.

> Ajuste `repoURL` em `bootstrap/*.yaml` e em cada `apps/**/*.yaml` para a URL
> real deste repositorio antes do primeiro bootstrap (usei
> `https://github.com/henriqzimer/argocd-k8s-homelab.git` como placeholder).

## Arquitetura

```
bootstrap/
  project.yaml      AppProject "homelab" (repos e destinos permitidos)
  root.yaml         Application "app-of-apps": aponta pra apps/ e cria as demais
apps/
  00-cluster/        Namespaces com labels de Pod Security Admission
  01-storage/        nfs-subdir-external-provisioner
  02-secrets/        vault, vault-secrets-operator, VaultAuth (CRs), vaultwarden
  03-networking/     metallb, cert-manager, traefik
  04-scheduling/     proxmox-ccm, karpenter, keda
  05-monitoring/     metrics-server, kube-prometheus-stack, portainer
  06-development/    argo-cd, gitlab-runner, k6-operator, n8n
  07-gaming/         romm, pcsx2, dolphin, xemu, eden
  08-security/       falco, kyverno, trivy-operator
  09-backup/         minio, velero
charts/              Charts locais que substituem os manifests com envsubst
                      do helmfile antigo (ClusterIssuer, IPAddressPool,
                      VaultStaticSecret, etc.) - values fixos, sem variavel
                      de ambiente em tempo de apply
values/              Os mesmos values.yaml do helm-k8s-homelab, um por app
scripts/             Apenas o que ainda e necessario fora do Argo CD:
                      bootstrap do secret do Postgres do Vault e seed dos
                      secrets de aplicacao no Vault
```

Cada `Application` em `apps/` usa (quando precisa de manifests extras) tres
fontes (`spec.sources`):

1. O chart Helm original, no repo publico de sempre (`chart:` + `repoURL`).
2. Este repositorio, so pra fornecer o `values.yaml` (`ref: values`).
3. Este repositorio, com um chart local em `charts/<app>-extras` pros
   recursos que antes eram manifests brutos aplicados via `envsubst` +
   `kubectl apply` (`scripts/apply-manifests.sh` no helmfile antigo).

Isso substitui o `envsubst`: o que era `${CLUSTER_DOMAIN}` no YAML agora e
`{{ .Values.clusterDomain }}` no chart local, com o valor fixo no
`values.yaml` do proprio chart - mesma filosofia que o repo original ja usava
pros `values.yaml` dos charts Helm (fonte unica de verdade, sem depender de
`.env` em tempo de apply).

## Ordem de instalacao (sync-waves)

O `helmfile.yaml` original usava `needs:` e hooks `presync`/`postsync`. Aqui a
ordem equivalente e a annotation `argocd.argoproj.io/sync-wave` em cada
`Application`:

| Wave | Apps |
|------|------|
| 0 | `cluster-bootstrap` (namespaces `networking`/`monitoring`/`scheduling`/`security` com labels PSA) |
| 1 | Apps sem dependencia: `nfs-subdir-external-provisioner`, `metrics-server`, `keda`, `k6-operator`, `pcsx2`, `dolphin`, `xemu`, `eden` |
| 2 | `hashicorp-vault` (precisa do namespace `storage` de pe) |
| 3 | `vault-secrets-operator` (precisa do Vault rodando) + `VaultAuthGlobal` |
| 4 | `vault-auth` (CRs `VaultAuth` por namespace, precisa do CRD do operator) |
| 5 | Tudo que so precisa do Vault Secrets Operator: `metallb`, `cert-manager`, `proxmox-cloud-controller-manager`, `karpenter-provider-proxmox`, `kube-prometheus-stack`, `portainer`, `argo-cd`, `gitlab-runner`, `n8n`, `vaultwarden`, `romm`, `loki`, `falco`, `kyverno`, `trivy-operator`, `vpa`, `minio` |
| 6 | `traefik` (precisa do `metallb` e do `cert-manager`), `promtail` (precisa do `loki`), `goldilocks` (precisa do `vpa`), `velero` (precisa do `minio`) |

Dentro de uma mesma `Application`, quando o secret precisa existir **antes**
do workload subir (ex.: `proxmox-ccm`, `karpenter`, `romm`), o
`VaultStaticSecret` tem `argocd.argoproj.io/sync-wave: "-1"` no chart local
pra sincronizar antes do Deployment do chart Helm.

Diferente do `helmfile apply` (que roda uma vez e para), o Argo CD com
`selfHeal: true` fica reconciliando: se um secret do Vault ainda nao existe, o
recurso so fica `Progressing`/`OutOfSync` ate existir, sem travar o resto -
por isso os hooks `--wait-secrets` do script antigo nao tem equivalente direto
aqui, sao desnecessarios no modelo continuo do GitOps.

## Bootstrap de um cluster novo

1. **Secret do Postgres do Vault** (unico bootstrap manual, chicken-and-egg:
   o Vault precisa dele pra subir, e ele nao pode vir do proprio Vault):
   ```bash
   cp .env.example .env   # edite VAULT_POSTGRES_CONNECTION_URL
   make bootstrap-secret
   ```

2. **Argo CD** (tambem chicken-and-egg: precisa existir antes de poder se
   autogerenciar via GitOps):
   ```bash
   make bootstrap-argocd
   ```
   Isso instala o Argo CD uma vez via `helm upgrade --install` direto (usando
   o mesmo `values/development/argo-cd.yaml`), depois aplica o `AppProject` e
   a `Application` raiz (`root-homelab`). A partir daqui o proprio Argo CD
   assume: ele vai criar a `Application` `argo-cd` (em `apps/06-development`)
   que passa a gerenciar o Helm release do Argo CD a partir do Git - inclusive
   futuras mudancas de versao/values do proprio Argo CD passam a ser feitas
   editando `values/development/argo-cd.yaml` e dando `git push`.

3. Acompanhe a sincronizacao:
   ```bash
   kubectl get applications -n development -w
   ```
   As waves respeitam a ordem da tabela acima automaticamente.

4. **Seed dos secrets de aplicacao no Vault** (mesma logica do helmfile
   antigo - Grafana, Portainer, Cloudflare/cert-manager, Proxmox, RomM,
   Vaultwarden, MinIO, Talos worker user-data):
   ```bash
   make seed-vault-secrets
   ```
   Pode rodar antes ou depois do Argo CD sincronizar os apps que dependem
   desses secrets - com `selfHeal` eles convergem sozinhos assim que o Vault
   Secrets Operator sincroniza o `VaultStaticSecret` correspondente.

## O que NAO precisa mais existir

Comparado ao `helm-k8s-homelab`, os seguintes scripts do helmfile antigo
foram substituidos pelo proprio Argo CD e nao tem equivalente aqui:

- `scripts/apply-manifests.sh` (envsubst + kubectl apply) -> viraram os
  charts locais em `charts/*-extras`.
- `scripts/apply-vault-auths.sh` -> chart `charts/vault-auth`.
- `scripts/ensure-namespaces.sh` -> `syncOptions: [CreateNamespace=true]` em
  cada `Application` + chart `charts/cluster-bootstrap` pros labels PSA.
- `scripts/wait-talos-worker-config.sh` e `scripts/check-prereqs.sh` -> nao
  fazem sentido num modelo de reconciliacao continua com `selfHeal`.
- `scripts/destroy-namespaces.sh` -> `finalizers:
  [resources-finalizer.argocd.argoproj.io]` na `Application` raiz cuida da
  limpeza em cascata ao deletar `root-homelab`.

`scripts/seed-vault-secrets.sh` e `scripts/ensure-vault-postgres-secret.sh`
continuam existindo porque populam segredos **dentro do Vault**, algo
ortogonal ao motor de sync (helmfile ou Argo CD nao fazem isso por voce em
nenhum dos dois modelos).

## Trocar dominio, storage class, regiao do Proxmox etc.

Mesma regra do repo original: `values/**/*.yaml` e `charts/*-extras/values.yaml`
sao a unica fonte de verdade. Editar, commitar, dar push - o Argo CD aplica
sozinho (`selfHeal`) sem precisar rodar nada manualmente.

## Destruir o cluster

Delete a `Application` raiz com cascade (o finalizer cuida da ordem reversa
das waves):
```bash
kubectl delete application root-homelab -n development
```
