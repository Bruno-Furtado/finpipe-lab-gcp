
### Cenários

|  | Cenário 1 | Cenário 2 |
|--|-----------|-----------|
| Arquivos por dia | 100 | 100.000 |
| Registros por arquivo | 100.000 | 100.000 |
| Tamanho por arquivo | 5 MB | 5 MB |
| Volume ingerido por mês | ~15 GB | ~15 TB |
| Execuções do Workflow por mês | ~3.000 | ~3.000.000 |

> Os custos de armazenamento (Storage e BigQuery) são cumulativos pois o dado de janeiro ainda existe em dezembro.

---

### Cloud Storage

**Referência de preço:** Standard, us-central1:  $0,002/GB/mês (free tier de 5 GB desconsiderado)

| | Mês 1 | Mês 12 | Total 12 meses |
|-|-------|--------|----------------|
| Cenário 1 | ~$0,03 | ~$0,36 | ~$2,34 |
| Cenário 2 | ~$30,00 | ~$360,00 | ~$2.340,00 |

> No Cenário 2, migrar dados históricos para a classe Archive ($0,00012/GB/mês) reduziria o custo em mais de 90%.

---

### EventArc

Eventos de finalização de objeto no GCS direcionados a uma Cloud Run Function são gratuitos (tráfego interno ao Google não é cobrado).

---

### Cloud Run Function

**Referência de preço:** $0,40/1M invocações (free tier de 2 M/mês), 400 K GB-segundo de compute gratuitos/mês

| | Invocações/mês | Custo |
|-|----------------|-------|
| Cenário 1 | ~3.000 | — (free tier) |
| Cenário 2 | ~3.000.000 | ~$0,40/mês |

---

### Pub/Sub

O custo de publicação e entrega de mensagens é irrelevante nos dois cenários: o free tier de 10 GB/mês cobre o volume de dados trafegados para a BigQuery Subscription considerando o tamanho médio por registro (metadados são enviados, não o arquivo em si).

---

### Cloud Workflows

**Referência de preço:** 5.000 etapas internas gratuitas/mês, $0,01/1.000 etapas adicionais

Assumindo 30 etapas por execução do workflow:

| | Etapas/mês | Custo |
|-|------------|-------|
| Cenário 1 | 30 × 3.000 = 90.000 | ~$0,85/mês |
| Cenário 2 | 30 × 3.000.000 = 90.000.000 | ~$29,95/mês × 12 = ~$359,40 |

---

### BigQuery — Ingestão

O carregamento via BigQuery Subscription é classificado como ingestão batch e não gera custo de processamento.

---

### BigQuery — Armazenamento

**Referência de preço:** lógico, us-central1 (free tier de 10 GB): $0,02/GB/mês

| | Mês 1 | Mês 12 | Total 12 meses |
|-|-------|--------|----------------|
| Cenário 1 | ~$0,10 | ~$3,40 | ~$21,00 |
| Cenário 2 | ~$300,00 | ~$3.600,00 | ~$23.400,00 |

> No Cenário 2, vale avaliar:
> - **Physical billing** (cobrança pelo armazenamento físico) pode reduzir o custo em 30–70%.
> - **TTL por partição** elimina dados antigos automaticamente, reduzindo o crescimento do histórico.
> - **Particionamento por data** já implementado na camada raw limita o volume varrido nas queries de transformação.

---

### BigQuery — Processamento

**Referência de preço:** on-demand, us-central1: $6,25/TB (free tier de 1 TB/mês)

Supondo que as queries de transformação (silver + gold) e as consultas analíticas leem aproximadamente 10× o volume ingerido no mês:

| | Dados lidos/mês | Custo |
|-|-----------------|-------|
| Cenário 1 | ~150 GB | — (free tier) |
| Cenário 2 | ~150 TB | ~$78,00/mês |

---

### Resumo

**Cenário 1 — 100 arquivos/dia · 5 MB/arquivo**

| Serviço | Mês 1 | Mês 12 | 12 meses |
|---------|-------|--------|----------|
| Cloud Storage | ~$0,03 | ~$0,36 | ~$2,34 |
| EventArc | — | — | — |
| Cloud Run Function | — | — | — |
| Pub/Sub | — | — | — |
| Cloud Workflows | — | — | — |
| BigQuery (armazenamento) | ~$0,10 | ~$3,40 | ~$21,00 |
| BigQuery (processamento) | — | — | — |
| **Total estimado** | **~$0,13** | **~$3,76** | **~$23,34** |

**Cenário 2 — 100.000 arquivos/dia · 5 MB/arquivo**

| Serviço | Mês 1 | Mês 12 | 12 meses |
|---------|-------|--------|----------|
| Cloud Storage | ~$30,00 | ~$360,00 | ~$2.340,00 |
| EventArc | — | — | — |
| Cloud Run Function | ~$0,40 | ~$0,40 | ~$4,80 |
| Pub/Sub | — | — | — |
| Cloud Workflows | ~$29,95 | ~$29,95 | ~$359,40 |
| BigQuery (armazenamento) | ~$300,00 | ~$3.600,00 | ~$23.400,00 |
| BigQuery (processamento) | ~$78,00 | ~$78,00 | ~$936,00 |
| **Total estimado** | **~$408,35** | **~$4.068,35** | **~$27.040,20** |

---
