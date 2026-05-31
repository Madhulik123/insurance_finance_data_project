--this is final mart to connect with BI tools diretcly


{{
    config(
        materialized = 'table',
        partition_by = {
            "field": "calendar_date",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by = ['product_group_key', 'product_group_key']
    )
    }}

with fact as (

    Select * from {{ ref('fact_customers_daily') }}
),

dim_date as (

Select 
    calender_date,
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
    dd.calender_date,
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
    f.acquired_premium,
    f.user_id,
    f.daily_premium

    from fact as f
    left join dim_date as dd on f.calendar_date = dd.calender_date
    left join dim_product_group as dp on f.product_group_key = dp.product_group_key
)

Select * from final