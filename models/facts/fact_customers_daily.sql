--customer daily fact table
--This table is used for daily active customers and premium reporting 

{{
    config(
        materialized = 'table',
        partition_by = {
            'field': 'calendar_date',
            'data_type': 'date',
            'granularity': 'month'
        },
        cluster_by = ['product_group_key', 'user_id']
    )
}}

with stg as (
    select * from {{ ref('stg_pc_product_customers') }}
),

dim_date as (
    select * from {{ ref('dim_date') }}
),

dim_product_group as (
    select * from {{ ref('dim_product_group') }}
),

contracts_days as (
    select
        s.user_id,
        s.product_group,
        s.premium as monthly_premium,
        date(s.acquisition_date) as acquisition_date,
        date(s.started_at) as contract_start_date,
        date(s.churned_at) as contract_end_date,
        s.is_active,

        -- KPI 2: premium is a MONTHLY amount. Spread it across the days of the
        -- month so SUM(daily_premium) over any date range = premium collected
        -- in that range (handles partial months and flexible date filters).
        round(
            s.premium / extract(day from last_day(calendar_date, month)),
            6
        ) as daily_premium,

        -- KPI 3: acquired premium is booked once, on the contract start date.
        case
            when calendar_date = date(s.started_at)
            then s.premium
            else 0
        end as acquired_premium,
        calendar_date
    from stg as s
    cross join unnest(
        generate_date_array(
            date(s.started_at),
            greatest(
                date(s.started_at),
                coalesce(date(s.churned_at), current_date())
            )
        )
    ) as calendar_date
),

final as (
    select
        dd.date_key,
        dp.product_group_id,
        cd.calendar_date,
        cd.user_id,
        cd.product_group as product_group_key,
        cd.monthly_premium,
        cd.daily_premium,
        1 as active_contract_count,
        cd.acquired_premium,

        -- KPI 3: pre-computed running total so the BI tool only needs SUM/COUNT.
        sum(cd.acquired_premium) over (
            partition by cd.user_id
            order by cd.calendar_date
            rows between unbounded preceding and current row
        ) as accumulated_acquired_premium,

        cd.acquisition_date,
        cd.contract_start_date,
        cd.contract_end_date,
        cd.is_active,
        current_timestamp() as loaded_at
    from contracts_days as cd
    left join dim_date as dd on cd.calendar_date = dd.calendar_date
    left join dim_product_group as dp on lower(trim(cd.product_group)) = dp.product_group_key
)

select * from final