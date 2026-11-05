# Virtual keys

Não armazene virtual keys emitidas em YAML ou JSON no Git. Uma key é uma credencial de runtime, mesmo quando sua configuração tem origem declarativa.

Mantenha políticas padrão de geração e limites máximos na configuração LiteLLM. Para chaves de clientes, crie um fluxo separado que emita a key para o tenant, persista-a num secret apropriado e faça rotação/revogação via API. Derive team, modelos, budget e rate limit do arquivo declarativo do tenant. Na edição OSS, mantenha a key no backend e aplique `request_guardrails` ao montar cada chamada; fixar guardrails a uma virtual key é recurso Enterprise.
