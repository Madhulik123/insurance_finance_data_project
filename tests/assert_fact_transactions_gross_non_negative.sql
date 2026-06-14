-- Gross premium = processed charges before refunds, so it can never be negative.
-- A negative value means bad source data or a status-mapping bug. Returns offending rows.
select
    transaction_id,
    gross_premium_amount
from {{ ref('fact_transactions') }}
where gross_premium_amount < 0
