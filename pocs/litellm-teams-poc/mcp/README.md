# MCP servers

Esta POC registra `deepwiki_poc` no LiteLLM a partir de [`servers/deepwiki-poc.json`](servers/deepwiki-poc.json) e reconcilia o MCP `Studio` já existente a partir de [`servers/studio.json`](servers/studio.json). O Job [`sync/mcp-servers-job.yaml`](../sync/mcp-servers-job.yaml) lê os JSONs montados pelo Kustomize e chama `POST` para cadastrar ou `PUT` para atualizar pela API do LiteLLM. O `server_id` atual do Studio é preservado, então o Job atualiza o registro em vez de criar outro. Nenhum MCP é instalado no Kubernetes: os manifestos registram endpoints upstream no AI Gateway.

O DeepWiki também existe como exemplo estático em `values/development/litellm/40-mcp.yaml`; o alias `deepwiki_poc` é separado para testar o cadastro pela API sem substituir o registro existente. O Studio recebe seu token do caminho `k8s-homelab/litellm` no Vault, pela chave `STUDIO_MCP_TOKEN`. O Job usa essa variável para montar a URL em memória; o token não fica nos arquivos do Git. Depois da sincronização do Argo CD, liste as ferramentas com uma virtual key autorizada:

```bash
curl -sS "$LITELLM_URL/mcp-rest/tools/list?server_id=mcp-poc-deepwiki" \
  -H "Authorization: Bearer $LITELLM_API_KEY"

curl -sS "$LITELLM_URL/mcp-rest/tools/list?server_id=b3dc0a5e-c23a-49d5-b51d-ddf732389a67" \
  -H "Authorization: Bearer $LITELLM_API_KEY"
```

O reconciliador cria ou atualiza os servidores declarados; remover um JSON não apaga automaticamente o registro do banco. O token do Studio aparece na query da URL retornada pelo banco do LiteLLM, por isso não imprima a resposta completa de `GET /v1/mcp/server`. A concessão de acesso por key/team é separada do cadastro do servidor e deve ser explícita para uso fora desta POC.
