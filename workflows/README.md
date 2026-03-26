# Workflows

Orquestra as transformações BigQuery após cada ingestão: executa os procedures silver em paralelo e o gold em sequência, com polling nativo até a conclusão de cada job.


## Como executar

```bash
./workflows/deploy.sh
```


## Decisões técnicas

### Wait inicial (10s)
A escrita do Pub/Sub no BigQuery não é imediata, há uma latência entre a publicação da mensagem e a visibilidade do registro em `raw.landing_events`. O wait de 10s garante que a linha já esteja disponível antes de os procedures silver iniciarem a leitura, evitando que um job complete sem processar o evento recém-chegado.

### Silver em paralelo
`proc_transactions()` e `proc_customers()` são independentes, não compartilham tabelas de leitura nem de escrita. Executá-los em paralelo reduz o tempo total de processamento.

### Gold sequencial
`gold.proc_transactions()` faz join de `silver.transactions` com `silver.customers`, portanto só pode iniciar após ambos os branches silver concluírem. O bloco `parallel` do Workflows sincroniza automaticamente os dois branches antes de avançar para o próximo passo.

### Polling a cada 5s
O Cloud Workflows não oferece callback nativo para jobs BigQuery, é necessário polling ativo.

### Service Account dedicada
O Workflow usa uma SA própria (`finpipe-workflow-sa`) com apenas `bigquery.jobUser` e `bigquery.dataEditor`, sem acesso a Storage, Pub/Sub ou outros recursos do projeto.

### Parâmetros `audit_id` e `entity`
Recebidos da Cloud Run Function no momento do acionamento. Ficam registrados nos logs de execução do Cloud Workflows, permitindo relacionar cada execução com o arquivo que a originou sem instrumentação adicional.
