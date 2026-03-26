Criação dos datasets (`raw`, `silver`, `gold`) e de todas as tabelas, funções e procedures do pipeline.


## 🚀 Implantação

```bash
./bigquery/deploy.sh
```


## 📥 Camada RAW

Dados brutos ingeridos sem transformação. Serve como fonte de verdade: qualquer reprocessamento parte daqui.

### `raw.landing_events`

Recebe os eventos do Pub/Sub via subscription. Cada linha representa uma msg publicada pela Function ao detectar um arquivo no bucket.

| Campo | Tipo | Descrição |
|---|---|---|
| `subscription_name` | STRING | Nome da subscription que entregou a mensagem |
| `message_id` | STRING | ID único da mensagem Pub/Sub — usado para deduplicação |
| `publish_time` | TIMESTAMP | Data/hora de publicação — coluna de partição |
| `data` | JSON | Payload do arquivo (path, bucket, entity, registros, etc.) |
| `attributes` | JSON | Metadados adicionais, incluindo o `audit_id` gerado pela Function |


## 🪙 Camada Silver

Dados limpos e normalizados, particionados pela data da ingestão. O MERGE incremental garante idempotência.

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

### Funções

- `silver.normalize_customer_id`: normaliza o id removendo zeros à esquerda do número: (D001 → D1).

### Procedures

- `silver.proc_customers()`: lê a tabela de eventos, deduplica e faz MERGE em na tabela silver
- `silver.proc_transactions()`: lê a tabela de eventos, deduplica e faz MERGE em na tabela silver

> Ambas usam uma janela de lookback de 7 dias para evitar full scans na tabela de eventos.


## 🥇 Camada Gold

Tabela pronta para análise, particionada pela data de ingestão e clusterizada.

### `gold.transactions`

Join das tabelas de transactions e customers da silver, evitando que analistas precisem fazer joins manualmente a cada query.

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

- `gold.proc_transactions()`: faz join da transactions com a customers (ambas silver) e faz MERGE na transactions (gold).

### Views

| View | Descrição |
|---|---|
| `gold.transactions_monthly_ttm_vw` | Volume e valor de transações por mês nos últimos 12 meses, com breakdown por status (approved/pending/rejected) e taxa de rejeição |
| `gold.transactions_daily_avg_price_vw` | Preço médio diário e acumulado de compras aprovadas, excluindo a primeira transação de cada cliente (onboarding) |
| `gold.transactions_customers_last_quarter_vw` | Resumo por cliente (volume e valor por status) filtrado ao último trimestre com dados |

---

## 🧠 Decisões técnicas

### Região do dataset
- `us-central1`: mesma região do bucket no Cloud Storage.
- Um dataset para todos os dados brutos (raw), simplicidade de gestão.

### Billing type (logical bytes)
- `logical`: cobrança baseada nos bytes lógicos armazenados, sem considerar compressão interna do BQ.

### Tabela `landing_events`
- Todas as entidades (`transactions`, `customers`) são publicadas no mesmo tópico e caem na mesma tabela raw.
- Partitionada pelo `publish_time` (dia). Alinhado com o padrão de ingestão diária do pipeline.

### Tipo `data` como JSON
- O Pub/Sub envia o payload como string. Usar o tipo `JSON` no BQ (maior flexibilidade).

### Expiração de partição
- Não configurada, mas poderia existir para evitarmos muitos dados após longo períodos (mais de 10 anos, por exemplo).
