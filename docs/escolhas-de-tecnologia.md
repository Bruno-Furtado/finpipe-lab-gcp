# 🧠 Escolhas de tecnologia

### Cloud Storage + Particionamento Hive
**Ferramenta padrão:** O Cloud Storage é o serviço nativo do GCP para armazenamento de objetos e blobs. A estrutura de particionamento Hive (`entity=transactions/`, `entity=customers/`) é um padrão de mercado e, com ele, é possivel buscar arquivos de maneira eficiente.

### EventArc
**Elimina a necessidade de polling ou agendadores:** assim que um arquivo é finalizado no GCS, o evento é detectado e a Cloud Run Function é invocada automaticamente. O gatilho é limitado apenas às pastas `entity=*/`, evitando invocações indesejadas. Aqui é esperado um evento por dia sem paralelismo (até pode-se receber mais de um evento por dia, mas sem paralelismo).

> Para volumes maiores/paralelismo, os eventos poderiam ser acionamos por um aquivo (sentinel file), sinalizando que um job terminou.

### Cloud Run Function
**Responsabilidade única:** receber o evento, validar o arquivo, publicar no Pub/Sub e acionar o Workflow. Sem infraestrutura para gerenciar e escala automaticamente. Em caso de falha (arquivo inválido, erro de publicação), alertas são disparados via Cloud Monitoring sem nenhuma configuração adicional de código.

### Pub/Sub
**Desacopla a ingestão do processamento:** A subscription do BigQuery persiste automaticamente cada mensagem JSON em uma tabela, junto com seus metadados. Todos os atributos são armazenados em colunas permitindo rastreabilidade de ponta a ponta do Log Explorer até a camada gold. Uma Dead Letter Queue (DLQ) retém mensagens não entregues por até 7 dias, com alertas automáticos. Aqui, conseguimos receber arquivos CSV independente das colunas existentes no mesmo.

### Cloud Monitoring + Log Explorer
**O Cloud Monitoring centraliza os alertas:** erros da Function, erros do Workflow e mensagens acumuladas na DLQ disparam notificações por e-mail. O Log Explorer permite rastrear o id de auditoria em todas as etapas do pipeline, dos logs estruturados da Function aos metadados nas tabelas silver e gold.

### Cloud Workflows
**Orquestra as transformações:** Executa os procedimentos silver em paralelo (transações e clientes são independentes) e, após ambos finalizarem, executa o procedimento gold sequencialmente.

### BigQuery + Arquitetura Medalhão
Três camadas com responsabilidades distintas:
- **raw:** dados brutos exatamente como recebidos do Pub/Sub, imutáveis. Particionados por data para evitar full scan.
- **silver:** dados limpos, normalizados e deduplicados. O MERGE incremental garante idempotência.
- **gold:** tabela pronta para analytics, enriquecida com um join entre transações e clientes, com particionamento e clusterização.
