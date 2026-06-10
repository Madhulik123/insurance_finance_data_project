{{ config(
    materialized = 'table'
) }}

-- Reconciliation between Finance (raw transactions) and Accounting monthly closing.
-- Empirically, the Accounting closing aligns with GROSS premium (processed charges,
-- before refunds), so gross is the primary comparison figure. Net premium and the
-- refund impact are surfaced alongside so the business can see the earned-premium gap.

with finance as (

    select
        party_name,
        month,
        gross_premium_amount as finance_gross_premium,
        net_premium_amount   as finance_net_premium
    from {{ ref('mart_monthly_premiums') }}

),

accounting as (

    select
        lower(trim(party)) as party,
        month,
        cast(premium as numeric) as accounting_premium
    from {{ ref('accounting_monthly_closing') }}

),

reconciled as (

    select
        coalesce(lower(f.party_name), a.party) as party_name,
        coalesce(f.month, a.month)             as month,
        f.finance_gross_premium,
        f.finance_net_premium,
        a.accounting_premium,

        -- primary reconciliation: gross vs accounting
        round(coalesce(f.finance_gross_premium, 0) - coalesce(a.accounting_premium, 0), 2) as gross_vs_accounting_diff,

        -- refund impact (gross minus net) = premium given back to customers
        round(coalesce(f.finance_gross_premium, 0) - coalesce(f.finance_net_premium, 0), 2) as refund_impact

    from finance as f
    full outer join accounting as a
        on lower(f.party_name) = a.party
        and f.month = a.month

)

select
    *,
    case
        when accounting_premium is null then 'Accounting value is missing'
        when finance_gross_premium is null then 'Finance value is missing'
        when abs(gross_vs_accounting_diff) < 0.01 then 'Match'
        else 'Difference'
    end as match_status
from reconciled
order by party_name, month
