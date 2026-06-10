--this is final mart to connect with BI tools diretcly


{{
    config(
        materialized = 'table',
        cluster_by = ['product_group_key', 'user_id']
    )
}}


with fact as (

    Select * from {{ ref('fact_customers_daily') }}
),

dim_date as (

Select 
    calendar_date,
    year,
    quarter,
    month,
    month_short,
    month_start_date,
    year_month,
    week_number,
    is_weekend,
    week_start_date
    from {{ ref('dim_date') }}
),

dim_product_group as (

    Select 
     product_group_key,
     product_group_name,
     product_category
    from {{ ref('dim_product_group') }}
),

final as (

Select 
    f.contract_start_date,
    f.contract_end_date,
    f.loaded_at,
    dd.calendar_date,
    dd.year,
    dd.quarter,
    dd.month,
    dd.month_short,
    dd.month_start_date,
    dd.year_month,
    dd.week_number,
    dd.is_weekend,
    dd.week_start_date,
    dp.product_group_key,
    dp.product_group_name,
    dp.product_category,

    --KPIs for dashboards
    f.user_id,
    f.active_contract_count,                 -- SUM -> active customers per day/product group
    f.daily_premium,                         -- SUM -> premium collected in a date range
    f.monthly_premium,                       -- original monthly contract premium
    f.acquired_premium,                      -- premium booked on contract start date
    f.accumulated_acquired_premium           -- pre-computed running total to each date

    from fact as f
    left join dim_date as dd on f.calendar_date = dd.calendar_date
    left join dim_product_group as dp on f.product_group_key = dp.product_group_key
)

Select * from final