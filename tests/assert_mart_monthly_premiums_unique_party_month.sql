-- mart_monthly_premiums is the finance side of the reconciliation and must be one row
-- per party per month. A duplicate here fans out the FULL OUTER JOIN in
-- mart_finance_vs_accounting_cal and corrupts every reconciliation figure for that party/month.
select
    party_name,
    month,
    count(*) as row_count
from {{ ref('mart_monthly_premiums') }}
group by party_name, month
having count(*) > 1
