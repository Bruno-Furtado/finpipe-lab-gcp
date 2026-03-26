# Pub/Sub

Criação do tópico, Dead Letter Topic e subscription BigQuery para receber e persistir os eventos publicados pela Cloud Run Function.


## Como executar

```bash
./pubsub/deploy.sh
```

---

## Decisões técnicas

### Write Metadata
Habilitado via `--write-metadata` — faz o Pub/Sub gravar o schema padrão do Google na tabela BigQuery: `message_id`, `publish_time`, `data` (JSON) e `attributes` (JSON).

### Retenção da subscription
- **Lab e Produção:** 7 dias — janela de reprocessamento caso o BigQuery rejeite mensagens ou haja necessidade de redelivery. Alinhado com o prazo de retenção da DLQ para que ambos cubram o mesmo período de recuperação.

### Dead Letter Topic
- **Lab:** Habilitado com máximo de 5 tentativas e retenção de 7 dias. Após 5 falhas consecutivas de entrega ao BigQuery, a mensagem é movida para o DLT em vez de ser descartada.
- **Produção:** Adicionar uma subscription no DLT para reprocessamento automático (ex: Cloud Function que rereads e republica a mensagem após correção do problema).

### Alerta
- **Lab:** Email disparado quando qualquer mensagem cair no DLT — sinal imediato de falha na entrega, sem necessidade de monitorar o console ativamente.
- **Produção:** Adicionar canal Slack e alertas de latência (`oldest_unacked_message_age`) para detectar lentidão antes que mensagens comecem a acumular na fila.
