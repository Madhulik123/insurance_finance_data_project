-- Premium amounts are summed across transactions WITHOUT any FX conversion.
-- If more than one currency is present, every premium total (and the accounting
-- reconciliation) is silently wrong. This test fails the moment a second currency appears.
select
    count(distinct premium_currency) as currency_count
from {{ ref('fact_transactions') }}
having count(distinct premium_currency) > 1
