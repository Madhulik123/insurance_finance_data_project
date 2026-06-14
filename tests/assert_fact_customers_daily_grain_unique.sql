-- Grain of fact_customers_daily is one row per customer, per product group, per day.
-- A duplicate at this grain double-counts active customers and daily premium.
-- (If a customer can legitimately hold two contracts in the same product group on the
--  same day, the source needs a contract_id and this key should be extended to include it.)
select
    user_id,
    product_group_key,
    calendar_date,
    count(*) as row_count
from {{ ref('fact_customers_daily') }}
group by user_id, product_group_key, calendar_date
having count(*) > 1
