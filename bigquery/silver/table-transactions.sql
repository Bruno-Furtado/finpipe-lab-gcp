create table if not exists `silver.transactions`
(
  transaction_id string options (description = 'Unique identifier of the transaction.'),
  customer_id string options (description = 'Identifier of the customer who made the transaction.'),
  transaction_date date options (description = 'Date when the transaction occurred. Used as partition column.'),
  transaction_amount float64 options (description = 'Total monetary value of the transaction.'),
  transaction_status string options (description = 'Current status of the transaction (e.g. completed, pending, failed).'),
  transaction_type string options (description = 'Type of transaction (e.g. purchase, refund).'),
  qtty float64 options (description = 'Quantity of items involved in the transaction.'),
  price float64 options (description = 'Unit price of the item at the time of the transaction.'),
  _ingested_at timestamp options (description = 'Timestamp when the file was ingested into the pipeline.'),
  _processed_at timestamp default current_timestamp() options (description = 'Timestamp when the record was processed by the silver transformation.'),
  _metadata struct<
    audit_id string options (description = 'Audit identifier set at ingestion time.'),
    message_id string options (description = 'Unique identifier of the Pub/Sub message.'),
    entity string options (description = 'Entity type (e.g. transactions).'),
    source_file string options (description = 'Name of the source file that originated the record.'),
    source_path string options (description = 'Full GCS path of the source file.'),
    publish_time timestamp options (description = 'Timestamp when the message was published to Pub/Sub.')
  > options (description = 'Pipeline metadata fields for traceability.')
)
partition by date(_ingested_at);