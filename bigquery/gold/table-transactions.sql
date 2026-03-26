create table if not exists `gold.transactions`
(
  transaction_id string options (description = 'Unique identifier of the transaction.'),
  customer_id string options (description = 'Identifier of the customer who made the transaction.'),
  customer_name string options (description = 'Full name of the customer.'),
  customer_email string options (description = 'Email address of the customer.'),
  transaction_date date options (description = 'Date when the transaction occurred.'),
  transaction_amount float64 options (description = 'Total monetary value of the transaction.'),
  transaction_status string options (description = 'Current status of the transaction (e.g. completed, pending, failed).'),
  transaction_type string options (description = 'Type of transaction (e.g. purchase, refund).'),
  qtty float64 options (description = 'Quantity of items involved in the transaction.'),
  price float64 options (description = 'Unit price of the item at the time of the transaction.'),
  _ingested_at timestamp options (description = 'Timestamp when the file was ingested into the pipeline.'),
  _processed_at timestamp default current_timestamp() options (description = 'Timestamp when the record was processed by the gold transformation.'),
  _metadata struct<
    audit_id_transactions string options (description = 'Audit identifier from the transactions silver table.'),
    audit_id_customers string options (description = 'Audit identifier from the customers silver table.')
  > options (description = 'Pipeline metadata fields for traceability.')
)
partition by date(_ingested_at)
cluster by transaction_status, transaction_type, customer_id;
