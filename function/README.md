Cloud Run Function que processa arquivos CSV enviados ao bucket, publica os dados no Pub/Sub e aciona o Cloud Workflows.


## 🔍 O que faz

1. Recebe evento do EventArc ao detectar novo arquivo no bucket (`google.cloud.storage.object.v1.finalized`)
2. Filtra apenas arquivos `.csv`, outros tipos são ignorados sem erro
3. Identifica a entidade pelo prefixo Hive do path (`entity=transactions/` ou `entity=customers/`)
4. Lê o CSV do GCS e serializa as linhas como JSON
5. Publica uma única mensagem no Pub/Sub com os dados e atributos de auditoria
6. Aciona o Cloud Workflows passando `audit_id` e `entity` como parâmetros


## 🚀 Implantação

```bash
./function/deploy.sh
```

## 💻 Desenvolvimento local

Instalar dependências:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
```

Rodar localmente:

```bash
PROJECT_ID=finpipe-lab TOPIC_ID=finpipe-landing-events WORKFLOW_ID=finpipe-pipeline LOCATION=us-central1 functions-framework --target=process --signature-type=cloudevent --debug
```

Simular um evento de upload (espera-se que o arquivo já esteja no storage):

```bash
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -H "ce-specversion: 1.0" \
  -H "ce-type: google.cloud.storage.object.v1.finalized" \
  -H "ce-source: //storage.googleapis.com/projects/_/buckets/finpipe-landing" \
  -H "ce-id: test-event-001" \
  -d '{
    "bucket": "finpipe-landing",
    "name": "entity=transactions/year=2026/month=03/day=24/transactions.csv",
    "contentType": "text/csv"
  }'
```

Lint e formatação:

```bash
ruff check .
ruff format .
```

---

## 🧠 Decisões técnicas

### Variáveis de ambiente
- `PROJECT_ID`, `TOPIC_ID` e `WORKFLOW_ID` são injetados via `--set-env-vars` no deploy (sem valores hardcoded no código).

### Uma mensagem por arquivo
- Todos os rows do CSV são publicados como uma única mensagem JSON.

### Validação de entidade
- Arquivos em paths não mapeados são ignorados com log de warning
- Erros de validação de conteúdo (CSV malformado, colunas ausentes) retornam erro e disparam alerta via Cloud Monitoring.

### Trigger via EventArc
- O evento é disparado apenas quando o upload é concluído com sucesso, garantindo que o arquivo esteja disponível antes da leitura.

### Instâncias
- `min=0`, `max=1`: sem custo em idle, processamento sequencial adequado para ingestão de poucos arquivos por dia
