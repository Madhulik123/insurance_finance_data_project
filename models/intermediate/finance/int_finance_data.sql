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

    -- DATA-QUALITY CORRECTION: a few source rows are status='processed' with a NEGATIVE
    -- amount. They don't follow the refund convention (refunds are status='refunded' with a
    -- POSITIVE amount), and the Accounting monthly closing books them as positive premium
    -- (abs() reconciles berlinre 2025-07 to the cent). We therefore treat them as
    -- sign-entry errors and correct the sign once here, so gross AND net both use the
    -- corrected charge consistently. Tracked by tests/assert_no_negative_processed_premium.sql
    -- (warn) so the source team is alerted if this pattern ever grows.
    case
        when lower(trim(status)) = 'processed' and premium_amount < 0
        then abs(premium_amount)
        else premium_amount
    end as corrected_premium_amount,

case
    when lower(trim(status)) = 'processed'
        then case when premium_amount < 0 then abs(premium_amount) else premium_amount end
    when lower(trim(status)) = 'refunded' then - premium_amount
    else 0
End as net_premium_amount,
case
            -- Gross = written premium; corrected charge is positive, so gross is never negative.
            when lower(trim(status)) = 'processed'
            then case when premium_amount < 0 then abs(premium_amount) else premium_amount end
            else 0
        end as gross_premium_amount
from stg

)   

Select * from premium_cal 
