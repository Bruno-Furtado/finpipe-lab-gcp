Orquestra as transformações BigQuery após cada ingestão.


## 🚀 Implantação

```bash
./workflows/deploy.sh
```


## 🧠 Decisões técnicas

### Wait inicial (5s)
- A escrita do Pub/Sub no BigQuery não é imediata, há uma latência entre a publicação da mensagem e a visibilidade do registro.
- O wait de 5s garante que a linha esteja disponível antes de os procedures silver iniciarem a leitura.

### Silver em paralelo
- Procedures são independentes, não compartilham tabelas de leitura nem de escrita. Executá-los em paralelo reduz o tempo total de processamento.

### Gold sequencial
- Procedure faz join das tabelas silvers, portanto só pode iniciar após ambos os branches silver concluírem.

### Polling a cada 5s
- O Cloud Workflows não oferece callback nativo para jobs BigQuery, sendo necessário polling ativo.

### Service Account dedicada
- O Workflow usa uma SA própria (finpipe-workflow-sa) com apenas as permissões necessárias.

### Parâmetros
- Recebidos da Cloud Run Function no momento do acionamento.
- Ficam registrados nos logs de execução do Workflows, permitindo relacionar cada execução com o arquivo que a originou.

### Alerta
- Email disparado em caso de falha na execução , o sinal é imediato sem necessidade de monitorar o console ativamente.
