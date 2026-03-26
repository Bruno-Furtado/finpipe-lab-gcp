# Storage

Criação do bucket no Cloud Storage para armazenamento dos arquivos CSV brutos que disparam o pipeline.


## Estrutura de pastas

```
finpipe-landing/
├── entity=transactions/
│   └── year=YYYY/month=MM/day=DD/
└── entity=customers/
    └── year=YYYY/month=MM/day=DD/
```

Formato Hive, padrão de mercado que permite ao BigQuery e ao Dataflow detectarem as colunas de partição automaticamente a partir do path, sem configuração adicional no schema. O prefixo `entity=` também é usado pela Cloud Run Function para identificar o tipo de dado sem precisar inspecionar o conteúdo do arquivo.

## Como executar

```bash
./storage/deploy.sh
```

---

## Decisões técnicas

### Região
- **Lab:** `us-central1` — mesma região dos outros serviços (BigQuery, Pub/Sub), eliminando cobranças por transferência de dados entre regiões e reduzindo latência na leitura pela tabela externa `raw.landing_gcs`
- **Produção:** Multi-region (`US`) - para redundância geográfica e maior disponibilidade

### Storage Class
- **Lab:** `STANDARD` — custo previsível e sem penalidade de acesso mínimo, adequado para arquivos acessados frequentemente durante testes
- **Produção:** `Autoclass` — migra objetos automaticamente entre Standard → Nearline → Coldline → Archive conforme o padrão de acesso, eliminando gestão manual e reduzindo custo de armazenamento histórico

### Soft Delete
- **Lab:** Desabilitado — facilita limpeza e reenvio de arquivos durante desenvolvimento sem custo adicional de retenção
- **Produção:** Habilitado com retenção mínima de 7 dias, permitindo recuperar arquivos excluídos acidentalmente sem depender de backup externo

### Política de Retenção
- **Lab:** Não configurada — permite excluir e reenviar arquivos livremente durante testes
- **Produção:** Retenção de meses (ex: 90 dias) - para bloquear a exclusão de arquivos financeiros durante o período de auditoria, garantindo conformidade com políticas de retenção regulatória

### Acesso Público
- **Lab e Produção:** Bloqueado (`--public-access-prevention`)
