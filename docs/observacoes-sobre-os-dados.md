# 🔍 Observações sobre os dados

### Consolidação dos arquivos de transações
Os dados de transações foram fornecidos em dois arquivos separados com colunas complementares: o primeiro continha os campos financeiros principais (valor, status, data) e o segundo os campos de composição (tipo, quantidade, preço). Como o formato oficialmente esperado pelo pipeline é um único arquivo consolidado com todas as colunas, os dois arquivos foram unidos antes da ingestão e se espera que assim sejam enviados futuramente.

### Envio dos arquivos ao bucket
O pipeline parte do princípio de que um serviço (interno ou externo) é responsável por depositar os arquivos no bucket. Esse serviço poderia ser, por exemplo, uma Cloud Function. Essa mesma Function poderia ainda atuar como controladora dos eventos: em cenários com múltiplos arquivos por job, ela seria responsável por aguardar a chegada de todos os arquivos esperados e, ao confirmar a conclusão, depositar um arquivo sentinela no bucket para sinalizar ao pipeline que o processamento pode ser iniciado.

### Normalização do id do customer
Foi identificada uma inconsistência no formato do id de clientes: o mesmo cliente aparecia como `C01` em um arquivo e `C1` em outro. Para garantir a integridade do JOIN entre transações e clientes na camada gold, foi criada uma função de normalização que padroniza o formato removendo zeros à esquerda após o prefixo.

### Atualizações de clientes
O pipeline já suporta o recebimento de arquivos de clientes contendo novos registros ou atualizações de registros existentes. O MERGE incremental na camada silver garante que os registros atualizados sobrescrevam as versões anteriores sem duplicação.

### Extensibilidade para novos campos
Se o CSV começar a incluir novas colunas, o pipeline absorve a mudança de forma transparente: os novos campos serão publicados no Pub/Sub e automaticamente persistidos na tabela de eventos como parte do payload JSON. Os dados já estarão armazenados no raw; para utilizá-los nas camadas silver e gold, basta ajustar os procedimentos correspondentes.
