create or replace procedure silver.proc_transactions()
begin

merge `silver.transactions` as target using (
-- OBTENDO OS ÚLTIMOS EVENTOS
with events as (
  select
    publish_time,
    message_id,
    json_value(attributes.audit_id) as audit_id,
    json_value(attributes.entity) as entity,
    safe_cast(json_value(attributes.ingested_at) as timestamp) as ingested_at,
    json_value(attributes.source_file) as source_file,
    json_value(attributes.source_path) as source_path,
    data
  from
    `raw.landing_events`
  where
    publish_time > (
      select coalesce(max(_metadata.publish_time), timestamp_micros(0))
      from `silver.transactions`
      where _ingested_at >= timestamp_sub(current_timestamp(), interval 7 day)
    ) -- obtém apenas os novos eventos
    and json_value(attributes.entity) = 'transactions'
  qualify 1 = row_number() over (partition by source_path order by ingested_at desc) -- obtém apenas os dados do último arquivo
)
-- TRATANDO OS DADOS
select
  nullif(json_value(r.transaction_id), '') as transaction_id,
  `silver.func_normalize_customer_id`(json_value(r.customer_id)) as customer_id,
  safe_cast(json_value(r.transaction_date) as date) as transaction_date,
  safe_cast(json_value(r.transaction_amount) as float64) as transaction_amount,
  nullif(json_value(r.transaction_status), '') as transaction_status,
  nullif(json_value(r.transaction_type), '') as transaction_type,
  safe_cast(json_value(r.qtty) as float64) as qtty,
  safe_cast(json_value(r.price) as float64) as price,
  e.ingested_at as _ingested_at,
  current_timestamp() as _processed_at,
  struct(e.audit_id, e.message_id, e.entity, e.source_file, e.source_path, e.publish_time) as _metadata
from
  events as e,
  unnest(json_extract_array(data)) as r
) as source on target.transaction_id = source.transaction_id

-- REALIZANDO O UPSERT
when matched and source._ingested_at > target._ingested_at then
update set
  customer_id = source.customer_id,
  transaction_date = source.transaction_date,
  transaction_amount = source.transaction_amount,
  transaction_status = source.transaction_status,
  transaction_type = source.transaction_type,
  qtty = source.qtty,
  price = source.price,
  _ingested_at = source._ingested_at,
  _processed_at = current_timestamp(),
  _metadata = source._metadata
when not matched then
  insert row;

end;
