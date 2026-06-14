-- Net premium = gross minus refunds, so net must never exceed gross for a transaction.
-- If it does, the net/gross CASE logic in int_finance_data is inconsistent. Returns offenders.
select
    transaction_id,
    gross_premium_amount,
    net_premium_amount
from {{ ref('fact_transactions') }}
where net_premium_amount > gross_premium_amount
