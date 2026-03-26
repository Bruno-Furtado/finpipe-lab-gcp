Criação do bucket no Cloud Storage para armazenamento dos arquivos CSV brutos que disparam o pipeline.


## 📁 Estrutura de pastas

```
finpipe-landing/
└── entity=<entity>/
    └── year=YYYY/
        └── month=MM/
            └── day=DD/
```

> Formato Hive, padrão de mercado que permite ao BigQuery detectar as colunas de partição automaticamente a partir do path, sem configuração adicional no schema.

## 🚀 Implantação

```bash
./storage/deploy.sh
```

## 🧠 Decisões técnicas

### Região
- Região `us-central1`, mesma região dos outros serviços (BigQuery, Pub/Sub), eliminando cobranças por transf. de dados entre regiões.

### Storage Class
- Class `STANDARD` pois possui custo previsível e sem penalidade de acesso mínimo, adequado os testes (acesso frequentemente).

### Soft Delete
- Recurso desabilitado para testes mas poderiamos habilitar a retenção mínima de 7 dias em produção.

### Política de Retenção
- Não configurada mas poderiamos habilitar a retenção de dias para bloquear exclusão de arquivos em produção.

### Acesso Privado
- Não há necessidade de acesso publico ao bucket.
