create or replace function silver.func_normalize_customer_id(id string) as (
  left(id, 1) || cast(substr(id, 2) as int64) -- C01 → C1 / D001 → D1 / C10 → C10
);