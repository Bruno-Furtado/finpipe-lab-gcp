create or replace procedure gold.proc_transactions()
begin

merge `gold.transactions` as target using (

-- TRATANDO OS ÚLTIMOS REGISTROS
select
  t.transaction_id,
  t.customer_id,
  c.customer_name,
  c.customer_email,
  t.transaction_date,
  t.transaction_amount,
  t.transaction_status,
  t.transaction_type,
  t.qtty,
  t.price,
  t._ingested_at,
  current_timestamp() as _processed_at,
  struct(
    t._metadata.audit_id as audit_id_transactions,
    c._metadata.audit_id as audit_id_customers
  ) as _metadata
from `silver.transactions` as t
left join `silver.customers` as c using (customer_id)
where
  t._ingested_at > (
    select coalesce(max(_ingested_at), timestamp_micros(0))
    from `gold.transactions`
    where _ingested_at >= timestamp_sub(current_timestamp(), interval 7 day)
  ) -- obtém apenas os novos registros
) as source
on target.transaction_id = source.transaction_id

-- REALIZANDO O UPSERT
when matched and source._ingested_at > target._ingested_at then
  update set
    customer_id = source.customer_id,
    customer_name = source.customer_name,
    customer_email = source.customer_email,
    transaction_date = source.transaction_date,
    transaction_amount = source.transaction_amount,
    transaction_status = source.transaction_status,
    transaction_type = source.transaction_type,
    qtty = source.qtty,
    price = source.price,
    _ingested_at = source._ingested_at,
    _processed_at = source._processed_at,
    _metadata = source._metadata
when not matched then
  insert row;

end;
