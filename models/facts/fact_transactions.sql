{{ config(
    materialized = 'table'
) }}


with transactions as (

select * from {{ ref('int_finance_data') }}

),

dim_date as (
    select
        date_key,
        calendar_date
    from {{ ref('dim_date') }}
),


dim_party as (

    Select 
        party_id,
        party_key
    from {{ ref('dim_party') }}
),

final as (

select 
    t.transaction_id,
    d.date_key,
    p.party_id,
    t.status as status_key,
    t.transaction_date,
    t.party as party_key,
    t.premium_currency,
    t.gross_premium_amount,
    t.net_premium_amount,
    current_timestamp() as loaded_at
from transactions as t
left join dim_date as d on t.transaction_date  = d.calendar_date
left join dim_party as p on t.party = p.party_key
)

Select * from final


