# 🧠 Por que essas tecnologias?

### Cloud Storage + Particionamento Hive
O Cloud Storage é o serviço nativo do GCP para armazenamento de objetos e blobs. A estrutura de particionamento Hive (`entity=transactions/`, `entity=customers/`) é um padrão de mercado e, com ele, é possivel buscar arquivos de maneira eficiente.

### EventArc
Elimina a necessidade de polling ou agendadores: assim que um arquivo é finalizado no GCS, o evento é detectado e a Cloud Run Function é invocada automaticamente. O gatilho é limitado apenas às pastas `entity=*/`, evitando invocações indesejadas. Para o volume esperado (um arquivos por dia), a invocação direta é ok. Já para volumes maiores e paralelismo, os eventos poderiam ser acionamos por um aquivo flag (sentinel file), sinalizando que um job terminou.

### Cloud Run Function
Responsabilidade única: receber o evento, validar o arquivo, publicar no Pub/Sub e acionar o Workflow. Sem infraestrutura para gerenciar, escala automaticamente de zero a 50 instâncias sob demanda. Em caso de falha (arquivo inválido, erro de publicação), alertas são disparados via Cloud Monitoring sem nenhuma configuração adicional de código.

### Pub/Sub
Desacopla a ingestão do processamento. A subscription do BigQuery persiste automaticamente cada mensagem JSON em `raw.landing_events`, junto com metadados como `message_id` e `publish_time`. Todos os atributos (incluindo o `audit_id` gerado pela Function) são armazenados na coluna `attributes`, permitindo rastreabilidade de ponta a ponta do Log Explorer até a camada gold. Uma Dead Letter Queue (DLQ) retém mensagens não entregues por até 7 dias, com alertas automáticos.

### Cloud Monitoring + Log Explorer
O Cloud Monitoring centraliza os alertas: erros da Function e mensagens acumuladas na DLQ disparam notificações por e-mail. O Log Explorer permite rastrear o `audit_id` em todas as etapas do pipeline, dos logs estruturados da Function aos campos `_metadata` nas tabelas Silver e Gold.

### Cloud Workflows
Orquestra as transformações. Aguarda alguns segundos após o evento antes de executar, garantindo que a escrita no raw esteja concluída. Executa os procedimentos silver em paralelo (transações e clientes são independentes) e, após ambos finalizarem, executa o procedimento gold sequencialmente. Polling nativo em intervalos de 5 segundos monitora cada job do BigQuery até sua conclusão.

### BigQuery — raw / silver / gold
Três camadas com responsabilidades distintas:
- **raw** — dados brutos exatamente como recebidos do Pub/Sub, imutáveis. Particionados por data para evitar full scan.
- **silver** — dados limpos, normalizados e deduplicados. O MERGE incremental garante idempotência: reprocessar o mesmo arquivo não gera duplicatas.
- **gold** — tabela pronta para analytics, enriquecida com um join entre transações e clientes. Particionada por data e clusterizada para otimizar a performance das consultas.
