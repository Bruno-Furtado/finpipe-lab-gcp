create table if not exists `silver.customers`
(
  customer_id string options (description = 'Unique identifier of the customer.'),
  customer_name string options (description = 'Full name of the customer.'),
  customer_email string options (description = 'Email address of the customer.'),
  _ingested_at timestamp options (description = 'Timestamp when the file was ingested into the pipeline.'),
  _processed_at timestamp default current_timestamp() options (description = 'Timestamp when the record was processed by the silver transformation.'),
  _metadata struct<
    audit_id string options (description = 'Audit identifier set at ingestion time.'),
    message_id string options (description = 'Unique identifier of the Pub/Sub message.'),
    entity string options (description = 'Entity type (e.g. customers).'),
    source_file string options (description = 'Name of the source file that originated the record.'),
    source_path string options (description = 'Full GCS path of the source file.'),
    publish_time timestamp options (description = 'Timestamp when the message was published to Pub/Sub.')
  > options (description = 'Pipeline metadata fields for traceability.')
)
partition by date(_ingested_at);
