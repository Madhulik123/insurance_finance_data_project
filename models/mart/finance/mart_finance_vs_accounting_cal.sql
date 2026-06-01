
--calculation for the finance and accounting team monthly closing match

with finance as (

    select 
    party_name,
    month,
    gross_premium_amount as finance_premium
    from {{ ref('mart_monthly_premiums') }}

),

accounting as (

Select 
    lower(trim(party)) as party,
     month,
    cast(premium as numeric) as accounting_premium
from {{ ref('accounting_monthly_closing') }}
)

Select 

coalesce(f.party_name,a.party) as party_name,
coalesce(f.month,a.month) as month,
f.finance_premium as finance_premium,
a.accounting_premium as accounting_premium,
round(coalesce(a.accounting_premium, 0) - coalesce(f.finance_premium, 0),2) as diff,
case 
when f.finance_premium = a.accounting_premium then 'Match' 
when f.party_name is null then 'Finace value is missing'
when a.party      is null then 'Accounting value is missing'
else 'Difference'

end as match_status


from finance as f 
full outer join accounting as a 
on f.party_name = a.party and f.month = a.month

order by party_name,month