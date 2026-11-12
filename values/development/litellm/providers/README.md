# Provider credentials

Modelos e aliases ficam em `../10-models.yaml`; credenciais de provedores ficam no Vault e são injetadas pelo Secret `litellm-secrets`. Nunca inclua API keys em values Helm versionados.

## Exemplo: Google Gemini

1. Cadastre `GEMINI_API_KEY` no Vault no caminho `k8s-homelab/litellm`, que alimenta o Secret `litellm-secrets`, e aguarde a sincronização.
2. Adicione este bloco em `values/development/litellm/10-models.yaml`:

```yaml
    - model_name: gemini-flash
      litellm_params:
        model: gemini/gemini-3.8-flash
        api_key: os.environ/GEMINI_API_KEY
```

3. Adicione `gemini-flash` à lista `models` de cada team que poderá usá-lo, por exemplo em `pocs/litellm-teams-poc/teams/guardrails-team.json`.
4. Faça commit e push. A alteração do catálogo dispara o rollout do gateway, que carrega a variável do Secret.
5. Gere uma virtual key para um desses teams e faça uma chamada usando `model: gemini-flash`.

Exemplo de chamada depois de gerar a virtual key:

```bash
curl -sS "$LITELLM_URL/v1/chat/completions" \
  -H "Authorization: Bearer $TENANT_LITELLM_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"gemini-flash","messages":[{"role":"user","content":"Resuma o que é Kubernetes em uma frase."}]}'
```

O alias (`gemini-flash`) é o nome estável que os clientes usam. O identificador do provedor segue o formato `gemini/<model-id>`; o exemplo usa `gemini/gemini-3.8-flash`, identificado pelo LiteLLM como provider Gemini. Confirme o model ID e a disponibilidade na sua conta antes de sincronizar. [Modelos Google Gemini](https://ai.google.dev/gemini-api/docs/models), [provider Gemini no LiteLLM](https://docs.litellm.ai/docs/providers/gemini)

Essa configuração usa uma credencial do projeto Google da plataforma. LiteLLM separa o spend por team para medição/chargeback, mas isso não faz cada cliente pagar diretamente com sua própria API key Google; BYOK por tenant precisa de um fluxo de credenciais separado.

## Outros provedores

Use o prefixo do provider LiteLLM e a variável correspondente no Vault:

```yaml
    - model_name: claude-sonnet
      litellm_params:
        model: anthropic/<model-id>
        api_key: os.environ/ANTHROPIC_API_KEY
```

Para um Llama servido pelo Ollama, adicione um item como este, substituindo a tag pela que aparece em `ollama list`:

```yaml
    - model_name: llama-local
      litellm_params:
        model: ollama_chat/llama3.1:8b
        api_base: http://ollama.development.svc.cluster.local:11434
```

Modelos locais usam `ollama_chat/<nome:tag>` e não precisam de chave cloud. O mesmo padrão de alias e allowlist de team se aplica.

## Usar Claude Pro pela assinatura

O LiteLLM não guarda os dados da sua conta Claude. O login da assinatura é feito no Claude Code, no computador do usuário; o Claude Code renova e encaminha o token OAuth em cada chamada. O proxy autentica separadamente com uma virtual key do próprio LiteLLM. Não crie nem cadastre `ANTHROPIC_API_KEY` para este fluxo. A assinatura e seus limites permanecem sob controle da Anthropic. [Guia oficial do LiteLLM](https://docs.litellm.ai/docs/tutorials/claude_code_max_subscription)

O catálogo declara `anthropic/*` em `10-models.yaml`. Para teste individual, a equipe `claude-pro-personal` permite esses modelos. Para acesso compartilhado com controle de membros, use a equipe `claude-subscription-users`, gerenciada em `pocs/litellm-teams-poc/teams/claude-subscription-users.json`. Ela concede acesso ao modelo somente aos usuários que forem adicionados à equipe no LiteLLM. Emita uma virtual key individual por usuário, vinculada à equipe; a chave autentica no gateway, não na Anthropic.

No terminal em que o Claude Code será usado, configure o endereço do gateway e a virtual key:

```bash
export LITELLM_API_KEY="<virtual-key-do-litellm>"
unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_MODEL
export ANTHROPIC_BASE_URL="https://litellm.henriqzimer.com.br"
export ANTHROPIC_CUSTOM_HEADERS="x-litellm-api-key: Bearer $LITELLM_API_KEY"
claude
```

Dentro do Claude Code, execute `/login` se ainda não estiver conectado, escolha a opção Claude Pro/Max e entre com a conta da assinatura. Se já houver uma sessão de API Console ativa, `/login` permite trocar para a assinatura. Depois escolha um modelo permitido pelo seu plano com `/model`. Não defina `ANTHROPIC_API_KEY` ou `ANTHROPIC_AUTH_TOKEN`: Claude Code envia seu token de assinatura no cabeçalho `Authorization`, e o cabeçalho `x-litellm-api-key` identifica a virtual key do LiteLLM.

Este fluxo é para chamadas do Claude Code. Outros clientes que aceitam somente uma API key estática não conseguem usar automaticamente a sessão OAuth da assinatura.
