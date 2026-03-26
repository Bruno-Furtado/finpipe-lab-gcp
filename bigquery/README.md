# BigQuery

Criação dos datasets (`raw`, `silver`, `gold`) e de todas as tabelas, funções e procedures do pipeline.


## Como executar

```bash
./bigquery/deploy.sh
```


## Camada RAW

Dados brutos ingeridos sem transformação. Serve como fonte de verdade: qualquer reprocessamento parte daqui.

### `raw.landing_events`

Recebe os eventos do Pub/Sub via subscription nativa. Cada linha representa uma mensagem publicada pela Cloud Function ao detectar um novo arquivo no bucket.

| Campo | Tipo | Descrição |
|---|---|---|
| `subscription_name` | STRING | Nome da subscription que entregou a mensagem |
| `message_id` | STRING | ID único da mensagem Pub/Sub — usado para deduplicação |
| `publish_time` | TIMESTAMP | Data/hora de publicação — coluna de partição |
| `data` | JSON | Payload do arquivo (path, bucket, entity, registros, etc.) |
| `attributes` | JSON | Metadados adicionais, incluindo o `audit_id` gerado pela Function |


## Camada Silver

Dados limpos e normalizados, particionados por `_ingested_at`. O MERGE incremental garante idempotência, reprocessar o mesmo arquivo não gera duplicatas.

### Funções

#### `silver.normalize_customer_id(id STRING)`

Normaliza o `customer_id` removendo zeros à esquerda do número: `C01 → C1`, `D001 → D1`, `C10 → C10`. Necessária para garantir integridade do JOIN na camada gold (o mesmo cliente aparecia com formatos diferentes nos arquivos de entrada).

### `silver.customers`

| Campo | Tipo | Descrição |
|---|---|---|
| `customer_id` | STRING | Identificador único normalizado |
| `customer_name` | STRING | Nome completo do cliente |
| `customer_email` | STRING | E-mail do cliente |
| `_ingested_at` | TIMESTAMP | Coluna de partição — timestamp de ingestão do arquivo |
| `_processed_at` | TIMESTAMP | Timestamp de processamento pela camada silver |
| `_metadata` | STRUCT | `audit_id`, `message_id`, `entity`, `source_file`, `source_path`, `publish_time` |

### `silver.transactions`

| Campo | Tipo | Descrição |
|---|---|---|
| `transaction_id` | STRING | Identificador único da transação |
| `customer_id` | STRING | Identificador do cliente |
| `transaction_date` | DATE | Data da transação |
| `transaction_amount` | FLOAT64 | Valor total da transação |
| `transaction_status` | STRING | Status (ex: completed, pending, failed) |
| `transaction_type` | STRING | Tipo (ex: purchase, refund) |
| `qtty` | FLOAT64 | Quantidade de itens |
| `price` | FLOAT64 | Preço unitário |
| `_ingested_at` | TIMESTAMP | Coluna de partição — timestamp de ingestão |
| `_processed_at` | TIMESTAMP | Timestamp de processamento |
| `_metadata` | STRUCT | `audit_id`, `message_id`, `entity`, `source_file`, `source_path`, `publish_time` |

### Procedures

- `silver.proc_customers()` — lê `raw.landing_events` (entity=customers), deduplica por `source_path` e faz MERGE em `silver.customers`
- `silver.proc_transactions()` — lê `raw.landing_events` (entity=transactions), deduplica por `source_path` e faz MERGE em `silver.transactions`

Ambas usam uma janela de lookback de 7 dias para evitar full scans em `raw.landing_events`, alinhada ao período de retenção da subscription do Pub/Sub.


## Camada Gold

Tabela desnormalizada pronta para análise, particionada por `_ingested_at` e clusterizada por `transaction_status`, `transaction_type`, `customer_id`.

### `gold.transactions`

Join de `silver.transactions` com `silver.customers`. Inclui todos os campos de transação mais `customer_name` e `customer_email`, evitando que analistas precisem fazer joins manualmente a cada query.

| Campo | Tipo | Descrição |
|---|---|---|
| `transaction_id` | STRING | Identificador único da transação |
| `customer_id` | STRING | Identificador do cliente |
| `customer_name` | STRING | Nome do cliente (de silver.customers) |
| `customer_email` | STRING | E-mail do cliente (de silver.customers) |
| `transaction_date` | DATE | Data da transação |
| `transaction_amount` | FLOAT64 | Valor total |
| `transaction_status` | STRING | Status da transação |
| `transaction_type` | STRING | Tipo da transação |
| `qtty` | FLOAT64 | Quantidade |
| `price` | FLOAT64 | Preço unitário |
| `_ingested_at` | TIMESTAMP | Coluna de partição |
| `_processed_at` | TIMESTAMP | Timestamp de processamento |
| `_metadata` | STRUCT | `audit_id_transactions`, `audit_id_customers` |

### Procedures

- `gold.proc_transactions()` — faz join de `silver.transactions` com `silver.customers` e faz MERGE em `gold.transactions`

### Views

| View | Descrição |
|---|---|
| `gold.transactions_monthly_ttm_vw` | Volume e valor de transações por mês nos últimos 12 meses, com breakdown por status (approved/pending/rejected) e taxa de rejeição |
| `gold.transactions_daily_avg_price_vw` | Preço médio diário e acumulado de compras aprovadas, excluindo a primeira transação de cada cliente (onboarding) |
| `gold.transactions_customers_last_quarter_vw` | Resumo por cliente (volume e valor por status) filtrado ao último trimestre com dados |

---

## Decisões técnicas

### Região do dataset
- **Lab e Produção:** `us-central1` — mesma região do bucket no Cloud Storage. Obrigatório: o Pub/Sub não consegue entregar mensagens para uma tabela BigQuery em região diferente do tópico.

### Billing type (logical bytes)
- **Lab e Produção:** `logical` — cobrança baseada nos bytes lógicos armazenados, sem considerar compressão interna do BQ. Mais previsível para monitoramento de custos; o modelo `physical` pode ser vantajoso em tabelas muito grandes com alta taxa de compressão, mas exige análise prévia do padrão de dados.

### Tabela `landing_events`
Todas as entidades (`transactions`, `customers`) são publicadas no mesmo tópico e caem na mesma tabela raw. A separação por entidade ocorre nas procedures silver via filtro no campo `attributes.entity`.

### Tipo `data` como JSON
O Pub/Sub envia o payload como string. Usar o tipo `JSON` no BQ permite navegar os campos diretamente com `JSON_VALUE(data.field)` sem precisar de `PARSE_JSON` em cada query.

### Particionamento por `publish_time` (DAY) — `landing_events`
Alinhado com o padrão de ingestão diária do pipeline. Queries que filtram por data leem apenas a partição relevante, evitando full scan em uma tabela que cresce indefinidamente.

### Expiração de partição
- **Lab:** Não configurada
- **Produção:** Configurar expiração após alguns anos (ex: 5 anos) para conformidade com políticas de retenção de dados financeiros e evitar crescimento indefinido de custo de armazenamento.

### Dataset único `raw`
- **Lab:** Um dataset para todos os dados brutos — simplicidade de gestão
- **Produção:** Considerar separação por domínio (`raw_transactions`, `raw_customers`) para controle de acesso granular via IAM, permitindo que times diferentes acessem apenas os dados de sua responsabilidade
