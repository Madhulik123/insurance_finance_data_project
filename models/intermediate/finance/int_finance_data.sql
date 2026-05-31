{{ config(
    materialized = 'view'
) }}



with 

stg as ( 
    select * from  {{ ref('stg_raw_financial_data') }}
    ),

premium_cal as (

Select 
    transaction_id,
    created_at,
    date(created_at) as transaction_date,
    format_date('%Y-%m', date(created_at)) as year_month,
    extract(year from created_at) as transaction_year,
    extract(month from created_at) as transaction_month_num,
    charged_party as party,
    premium_currency,
    status,
    raw_status, 
case 
    when lower(trim(status)) = 'processed' then premium_amount
    when lower(trim(status)) = 'refunded' then - premium_amount
    else 0 
End as net_premium_amount,
case
            when lower(trim(status)) = 'processed'
            then premium_amount
            else 0
        end as gross_premium_amount,
loaded_at
from stg 

)   

Select * from premium_cal 
