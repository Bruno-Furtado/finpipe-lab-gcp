<div align="center">

  ![Cloud Storage](https://img.shields.io/badge/data-Cloud_Storage-3B82F6?style=flat)
  ![BigQuery](https://img.shields.io/badge/data-BigQuery-3B82F6?style=flat)
  ![Pub/Sub](https://img.shields.io/badge/events-Pub%2FSub-14B8A6?style=flat)
  ![EventArc](https://img.shields.io/badge/events-EventArc-14B8A6?style=flat)
  ![Cloud Run](https://img.shields.io/badge/compute-Cloud_Run-8B5CF6?style=flat)
  ![Workflows](https://img.shields.io/badge/compute-Workflows-8B5CF6?style=flat)
  ![Cloud Monitoring](https://img.shields.io/badge/observability-Cloud_Monitoring-F97316?style=flat)
  ![Log Explorer](https://img.shields.io/badge/observability-Log_Explorer-F97316?style=flat)
  ![Python](https://img.shields.io/badge/lang-Python-EAB308?style=flat)
  ![SQL](https://img.shields.io/badge/lang-SQL-EAB308?style=flat)
  ![YAML](https://img.shields.io/badge/lang-YAML-EAB308?style=flat)
  ![License](https://img.shields.io/badge/license-MIT-22c55e?style=flat)
</div>

<br/>

Pipeline orientado a eventos para ingestão, transformação e análise de transações financeiras no Google Cloud Platform.


## 🏗️ Arquitetura

1. **Arquivo CSV depositado** no bucket do GCS com partição Hive
2. **EventArc** detecta o evento de finalização do objeto e invoca a Cloud Run Function
3. **Cloud Run Function** valida o arquivo, gera um audit id único e publica os registros no Pub/Sub
4. **Pub/Sub** persiste o payload JSON na tabela da camada raw via subscription do BigQuery
5. **Cloud Workflows** aguarda a escrita no raw ser concluída, depois executa o silver em paralelo e o gold sequencialmente
6. **Silver** limpa, normaliza e deduplica os registros via MERGE incremental particionado
7. **Gold** enriquece os dados com um join de transações ✕ clientes, particionado e clusterizado para performance de consultas

Do depósito do arquivo até os dados disponíveis na camada gold, todo o fluxo é concluído em questão de segundos.


## 🧠 Por que essas tecnologias?

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


## 🔍 Observações sobre os dados

**Consolidação dos arquivos de transações**
Os dados de transações foram fornecidos em dois arquivos separados com colunas complementares: o primeiro continha os campos financeiros principais (valor, status, data) e o segundo os campos de composição (tipo, quantidade, preço). Como o formato oficialmente esperado pelo pipeline é um único arquivo consolidado com todas as colunas, os dois arquivos foram unidos antes da ingestão e se espera que assim sejam enviados futuramente.

**Envio dos arquivos ao bucket**
O pipeline parte do princípio de que um serviço (interno ou externo) é responsável por depositar os arquivos no bucket. Esse serviço poderia ser, por exemplo, uma Cloud Function. Essa mesma Function poderia ainda atuar como controladora dos eventos: em cenários com múltiplos arquivos por job, ela seria responsável por aguardar a chegada de todos os arquivos esperados e, ao confirmar a conclusão, depositar um arquivo sentinela (sentinel file) no bucket para sinalizar ao pipeline que o processamento pode ser iniciado.

**Normalização do `customer_id`**
Foi identificada uma inconsistência no formato do id de clientes: o mesmo cliente aparecia como `C01` em um arquivo e `C1` em outro. Para garantir a integridade do JOIN entre transações e clientes na camada gold, foi criada uma função de normalização (`silver.func_normalize_customer_id`) que padroniza o formato removendo zeros à esquerda após o prefixo.

**Atualizações de clientes**
O pipeline já suporta o recebimento de arquivos de clientes (`entity=customers/`) contendo novos registros ou atualizações de registros existentes. O MERGE incremental na camada silver garante que os registros atualizados sobrescrevam as versões anteriores sem duplicação.

**Extensibilidade para novos campos**
Se o CSV começar a incluir novas colunas, o pipeline absorve a mudança de forma transparente: os novos campos serão publicados no Pub/Sub e automaticamente persistidos em `raw.landing_events` como parte do payload JSON. Os dados já estarão armazenados no raw; para utilizá-los nas camadas silver e gold, basta ajustar os procedimentos correspondentes.


## ⚙️ Pré-requisitos

- Projeto GCP com faturamento habilitado
- [`gcloud`](https://cloud.google.com/sdk/docs/install) instalado e autenticado

> O Google recomenda conceder o **menor privilégio** necessário, preferindo papéis granulares. Neste lab, papéis mais amplos foram utilizados por simplicidade.


## 🚀 Implantação

Edite o [`config.sh`](./config.sh) com o ID do seu projeto e a região, depois execute cada etapa em ordem:

| # | Componente | Script | O que faz |
|---|-----------|--------|-----------|
| 1 | [Storage](./storage/) | `./storage/deploy.sh` | Cria o bucket de landing no GCS com particionamento Hive |
| 2 | [BigQuery](./bigquery/) | `./bigquery/deploy.sh` | Cria os datasets e as tabelas RAW / Silver / Gold |
| 3 | [Pub/Sub](./pubsub/) | `./pubsub/deploy.sh` | Cria o tópico, a subscription, a DLQ e os alertas por e-mail |
| 4 | [Workflows](./workflows/) | `./workflows/deploy.sh` | Implanta o pipeline de orquestração no Cloud Workflows |
| 5 | [Function](./function/) | `./function/deploy.sh` | Implanta a Cloud Run Function + gatilho EventArc |

> **Atalho:** `./deploy.sh` executa as cinco etapas sequencialmente.


## 🧪 Testes

Com a infraestrutura implantada, o pipeline pode ser acionado depositando os arquivos diretamente no bucket via `gsutil`:

```bash
gsutil cp storage/files/normalized/customers.csv gs://finpipe-landing/entity=customers/year=2026/month=03/day=25/customers.csv
gsutil cp storage/files/normalized/transactions.csv gs://finpipe-landing/entity=transactions/year=2026/month=03/day=25/transactions.csv
```

Cada upload finalizado dispara automaticamente o EventArc, que invoca a Cloud Run Function e inicia o fluxo completo de ingestão e transformação.


## 📄 Licença

Este projeto está licenciado sob a [Licença MIT](./LICENSE).

---

<div align="center">
  <sub>Feito com ♥ em Curitiba 🌲 ☔️</sub>
  <br/>
  <sub>Construído com <a href="https://claude.ai/code">Claude Code</a> &nbsp;·&nbsp; mãos de IA, alma humana</sub>
</div>
