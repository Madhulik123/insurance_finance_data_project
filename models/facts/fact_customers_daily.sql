--customer daily fact table
--This table is used for daily active customers and premium reporting 

{{
    config(
        materialized = 'table',
        partition_by = {
            "field": "calendar_date",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by = ['product_group_key', 'user_id']
    )
    }}

with stg as (

    select * from {{ ref('stg_pc_product_customers') }}
),

dim_date as (

Select * from {{ ref('dim_date') }}
),

dim_product_group as (

Select * from {{ ref('dim_product_group') }}
),

contracts_days as (

    Select 
        s.user_id,
        s.product_group,
        s.premium,
        date(s.acquisition_date) as acquisition_date,
        date(s.started_at) as contract_start_date,
        date(s.churned_at) as contract_end_date,
        s.is_active,
         case
    when calendar_date = date(s.started_at)
    then s.premium
    else 0
    end as acquired_premium,
        calendar_date
        from stg as s,
        unnest ( 
            generate_date_array(
                date(s.started_at),
                --coalesce(date(s.churned_at), current_date())
                greatest(
                date(s.started_at),
                coalesce(date(s.churned_at), current_date())
        ))
    ) as calendar_date


),
final as (
Select 
 dd.date_key,
 dp.product_group_id,
 cd.calendar_date,
 cd.user_id,
 cd.product_group as product_group_key,
 cd.premium as daily_premium,
 1 as active_contract_count,
 cd.acquired_premium,
 cd.acquisition_date,
 cd.contract_start_date,
 cd.contract_end_date,
 cd.is_active,
 current_timestamp() as loaded_at

from contracts_days as cd 
left join dim_date as dd on cd.calendar_date = dd.calendar_date
left join dim_product_group as dp on cd.product_group = dp.product_group_key
)

Select * from final 