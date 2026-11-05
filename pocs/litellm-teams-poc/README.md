# LiteLLM GitOps POC

Esta POC complementa o gateway LiteLLM existente. Ela separa configuracao por dominio e evita concentrar todos os recursos em um unico values ou manifesto.

## Estrutura

```text
apps/06-development/litellm.yaml       # instalacao Helm e lista de values
values/development/litellm/
  00-infrastructure.yaml               # chart, banco, ingress e scheduling
  10-models.yaml                       # modelos, provedores e aliases
  20-guardrails.yaml                   # filtros
  30-policies.yaml                     # composicao e escopo das policies
  40-mcp.yaml                          # servidores MCP estaticos
  50-runtime.yaml                      # cache, fallback, auth e persistencia
pocs/litellm-teams-poc/
  teams/*.json                         # um arquivo declarativo por team
  sync/teams-job.yaml                 # reconciliador por API
  mcp/                                 # orientacao para MCPs dinamicos
  agents/                              # orientacao para agentes A2A
  skills/                              # orientacao para Skills Gateway
  keys/                                # orientacao para credenciais runtime
```

Os arquivos Helm são unidos pelo Argo CD na ordem listada em `apps/06-development/litellm.yaml`. Cada domínio tem seu próprio arquivo. Os valores dos budgets, rate limits, modelos permitidos e metadados ficam junto ao team que os possui, em vez de espalhados por arquivos globais.

## Teams

| Team ID | Budget | Limites |
|---|---:|---|
| `cliente-a` | US$ 10 / 30 dias | 30 RPM, 10.000 TPM, 2 chamadas simultâneas; guardrail adicional |
| `cliente-b` | US$ 25 / 30 dias | 60 RPM, 30.000 TPM, 3 chamadas simultâneas; baseline global |

Cada team usa somente `qwen3-vl`. Os valores de preço desse modelo são fictícios para demonstrar budgets. Cada JSON descreve também `request_guardrails`, uma lista que o backend SaaS deve passar nas chamadas daquele cliente. O Job remove esse campo antes de chamar a API de Teams do LiteLLM.

Para adicionar um team, crie um JSON separado em `teams/` e inclua seu caminho em `configMapGenerator.files` no `kustomization.yaml`. O hook do Argo lê todos os JSONs montados e chama `/team/new` ou `/team/update`. Os nomes são IDs estáveis e os aliases devem ser exclusivos desta POC. Remover um arquivo do Git não apaga o team nem o histórico de spend no banco.

Exemplo de novo arquivo `teams/tenant-acme.json`:

```json
{
  "team_id": "tenant-acme",
  "team_alias": "tenant-acme",
  "models": ["qwen3-vl", "gemini-flash"],
  "max_budget": 50,
  "budget_duration": "30d",
  "rpm_limit": 120,
  "tpm_limit": 60000,
  "max_parallel_requests": 5,
  "request_guardrails": ["poc-team-guardrail"],
  "metadata": {"customer": "acme", "managed_by": "argocd"}
}
```

Inclua `teams/tenant-acme.json` em `configMapGenerator.files`; depois do push, o Argo provisiona ou atualiza esse team. A criação de uma virtual key do tenant continua sendo um passo separado, pois a key emitida é um segredo runtime.

## Adicionar um modelo

Para Gemini, siga o exemplo em [`values/development/litellm/providers/README.md`](../../values/development/litellm/providers/README.md). Em resumo: adicione a credencial ao Vault, declare o alias no arquivo de modelos e permita esse alias na lista `models` dos teams que podem chamá-lo. Um team sem o alias não terá acesso àquele deployment.

## Regras globais e regras por cliente

`20-guardrails.yaml` define `pii-filter`, `injection-filter` e `poc-team-guardrail`. A policy global aplica PII a todos. O perfil de `cliente-a` também seleciona `poc-team-guardrail`, que bloqueia a frase `poc-guardrail-secret`; `cliente-b` não seleciona esse guardrail.

No fluxo SaaS, o backend autentica o usuário, resolve o `team_id` pelo tenant e monta a chamada ao LiteLLM. Para `cliente-a`, inclui a lista do perfil:

```json
{
  "model": "qwen3-vl",
  "messages": [{"role": "user", "content": "..."}],
  "guardrails": ["poc-team-guardrail"]
}
```

Para `cliente-b`, o backend envia `guardrails: []`; a policy global continua aplicada. O backend deve montar o campo a partir do perfil do tenant, sem aceitar que o cliente final escolha, remova ou acrescente guardrails.

**Limite da edição OSS:** `guardrails` é opcional por requisição. A associação obrigatória de guardrails a uma virtual key ou team exige LiteLLM Enterprise. Esta abordagem serve quando o SaaS guarda as virtual keys LiteLLM no backend e encaminha as chamadas. Não entregue a key diretamente ao cliente se o guardrail adicional for requisito de segurança: ele poderá chamar o gateway sem o parâmetro. [Guardrails por key e policies por team](https://docs.litellm.ai/docs/proxy/guardrails/quick_start)

Se o cliente precisa chamar o LiteLLM diretamente e o guardrail precisa ser obrigatório sem Enterprise, uma opção de isolamento é um gateway/configuração dedicada para esse cliente com o guardrail definido como `default_on: true`. Isso aumenta a quantidade de deployments e exige avaliar isolamento de banco, secrets, rede e operação.

## Recursos com lifecycle via API

Nem todo objeto do LiteLLM é um valor estático de Helm. Teams, virtual keys, servidores MCP registrados no banco, agentes e skills têm operações de API/UI e dados de runtime. Os diretórios correspondentes documentam a fronteira e o próximo passo, para não simular uma declaratividade que a configuração Helm não oferece.

- [MCP](mcp/README.md): configuração estática e permissões do gateway.
- [Agentes](agents/README.md): registro A2A e endpoint executável.
- [Skills](skills/README.md): catálogo e permissões de skills.
- [Keys](keys/README.md): emissão segura de credenciais e budgets por key.

O Job usa a master key do Secret `litellm-secrets`, já sincronizada pelo Vault. O gateway requer PostgreSQL para budgets e spend serem aplicados.
