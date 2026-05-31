{{ config(
    materialized = 'table'
) }}

--Creating the finance teams monthly net premium and gross premium logic for each party 
with transactions as (

    select *
    from {{ ref('fact_transactions') }}

),

parties as (

    select 
    party_id,
    party_name,
    party_type
     from {{ ref('dim_party') }}
)

Select 
p.party_name,
p.party_type,
format_date('%Y-%m', t.transaction_date) as month,
round(sum(t.gross_premium_amount),2) as gross_premium_amount,
round(sum(t.net_premium_amount),2) as net_premium_amount,
count(*) as transaction_count
from transactions as t
left join parties as p on t.party_id  = p.party_id 
group by 
p.party_name,
p.party_type,
month
order by month,
p.party_name




