create or replace view `gold.transactions_daily_avg_price_vw` as

with

-- remove primeira transação de cada cliente (abertura)
without_onboarding as (
  select
    *,
    qtty * price as total_cost
  from `gold.transactions`
  qualify row_number() over (partition by customer_id order by transaction_date, transaction_id) > 1
),

-- calcula preço médio acumulado + volume, só compras aprovadas
buys as (
  select
    transaction_date,
    transaction_id,
    qtty,
    total_cost,
    safe_divide(
      sum(total_cost) over (order by transaction_date, transaction_id),
      sum(qtty) over (order by transaction_date, transaction_id)
    ) as running_avg_price
  from without_onboarding
  where
    transaction_status = 'approved'
    and transaction_type = 'buy'
)

-- agrupa por dia: quantidade, preço médio do dia e preço médio acumulado
select
  transaction_date,
  sum(qtty) as buy_qtty,
  -- preço médio ponderado do dia (total_cost / qtty do dia)
  safe_divide(sum(total_cost), sum(qtty)) as daily_avg_price,
  -- preço médio acumulado (fechamento do dia, repete se sem compra)
  last_value(max(running_avg_price) ignore nulls) over (order by transaction_date) as running_avg_price,
  -- flag: 1 = registro com o preço médio atual
  row_number() over (order by transaction_date desc) as ranking
from buys
group by transaction_date