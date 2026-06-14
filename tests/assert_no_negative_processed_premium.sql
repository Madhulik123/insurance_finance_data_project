{{ config(severity = 'warn') }}

-- MONITORING (warn, non-blocking): surfaces source rows that are status='processed'
-- with a negative amount. int_finance_data treats these as sign-entry errors and
-- corrects them (see that model), so they don't corrupt premium figures. This test
-- keeps the anomaly visible: if the count grows beyond the known handful, the source
-- feed should be investigated rather than silently auto-corrected.
select
    transaction_id,
    created_at,
    premium_amount,
    charged_party,
    status
from {{ ref('stg_raw_financial_data') }}
where status = 'processed'
  and premium_amount < 0
