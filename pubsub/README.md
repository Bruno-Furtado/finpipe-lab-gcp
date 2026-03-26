Criação do tópico, Dead Letter Topic e subscription BigQuery para receber e persistir os eventos publicados pela Cloud Run Function.


## 🚀 Implantação

```bash
./pubsub/deploy.sh
```

---

## 🧠 Decisões técnicas

### Retenção da subscription
- 7 dias, alinhado com a janela de reprocessamento caso o BigQuery rejeite mensagens.

### Dead Letter Topic
- Habilitado com máximo de 5 tentativas e retenção de 7 dias.
- Após 5 falhas consecutivas de entrega ao BigQuery, a mensagem é movida para o DLT em vez de ser descartada e um alerta é enviado.