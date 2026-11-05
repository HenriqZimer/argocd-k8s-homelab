# Agents

Modelos de agente A2A podem ser organizados um arquivo por agente nesta pasta. O gateway LiteLLM cadastra um Agent Card e encaminha chamadas para um endpoint de agente; a implementação e a disponibilidade desse endpoint continuam sob responsabilidade do serviço do agente.

Para a próxima etapa, o reconciliador deve aplicar `/v1/agents` e permissões após o endpoint estar saudável. Não inclua tokens do agente nos arquivos declarativos.
