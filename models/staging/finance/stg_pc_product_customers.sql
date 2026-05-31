{{ config ( 
    materialized = 'view'
)}}

with source_data as (
select * from {{ source('product_customers', 'product_customers') }} 
),

data as (

    Select 
    trim(user_id) as user_id,
    cast(premium as numeric) as premium,
    lower(trim(product_group)) as product_group,
    cast(acquisition_date as timestamp) as acquisition_date,
    cast(started_at as timestamp) as started_at,
    cast(churned_at as timestamp) as churned_at,
    churned_at is null as is_active,
    date_diff(date(churned_at),date(started_at) ,day) as contract_duration_days,
    current_timestamp as loaded_at
    from source_data
    where user_id is not null
    and started_at is not null
    and premium is not null
    and premium > 0 
)

Select * from data 



