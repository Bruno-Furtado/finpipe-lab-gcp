create or replace view `gold.transactions_customers_last_quarter_vw` as
select
  customer_name,
  count(1) as total,
  countif(transaction_status = 'approved') as total_approved,
  countif(transaction_status = 'pending') as total_pending,
  countif(transaction_status = 'rejected') as total_rejected,
  sum(transaction_amount) as amount_total,
  sum(if(transaction_status = 'approved', transaction_amount, 0)) as amount_approved,
  sum(if(transaction_status = 'pending', transaction_amount, 0)) as amount_pending,
  sum(if(transaction_status = 'rejected', transaction_amount, 0)) as amount_rejected
from `gold.transactions`
where date_trunc(transaction_date, quarter) = (
  select max(date_trunc(transaction_date, quarter))
  from `gold.transactions`
)
group by all