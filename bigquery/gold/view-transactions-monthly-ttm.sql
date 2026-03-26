create or replace view `gold.transactions_monthly_ttm_vw` as
select
  date_trunc(transaction_date, month) as month,

  count(1) as total,
  countif(transaction_status = 'approved') as total_approved,
  countif(transaction_status = 'pending') as total_pending,
  countif(transaction_status = 'rejected') as total_rejected,

  sum(transaction_amount) as amount_total,
  sum(if(transaction_status = 'approved', transaction_amount, 0)) as amount_approved,
  sum(if(transaction_status = 'pending', transaction_amount, 0)) as amount_pending,
  sum(if(transaction_status = 'rejected', transaction_amount, 0)) as amount_rejected,

  safe_divide(countif(transaction_status = 'rejected'), count(1)) as rate_rejected_total,
  safe_divide(
    sum(if(transaction_status = 'rejected', transaction_amount, 0)),
    sum(transaction_amount)
  ) as rate_rejected_amount
from `finpipe-lab.gold.transactions`
group by all
qualify dense_rank() over (order by month desc) <= 12