# MCP servers

Configuração declarativa estática fica em `values/development/litellm/40-mcp.yaml`.

Quando o servidor precisa ser registrado no banco/UI, mantenha um manifesto por servidor nesta pasta e adicione ao reconciliador API em vez de misturar com os values Helm. Credenciais upstream devem vir do Vault/Secrets Manager. Conceda cada servidor às keys/teams explicitamente; a lista disponível no gateway não deve significar acesso irrestrito.
