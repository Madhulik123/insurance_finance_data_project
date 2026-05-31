{{ config(
    materialized = 'table'
) }}

with date_spine as (

    select calendar_date
    from unnest( generate_date_array('2024-01-01','2035-01-01')

) as calendar_date ),

date_fields as (
Select 
--surrogate key created for join in YYYYMMDD format
cast(format_date('%Y%m%d',calendar_date) as int64)          as date_key ,
calendar_date                                              as calendar_date, 
extract(year from calendar_date)                            as year,
extract(quarter from calendar_date)                         as quarter,
extract(month from calendar_date)                           as month,
format_date('%b', calendar_date)                            as month_short,
format_date('%Y-%m', calendar_date)                        as year_month,
date_trunc(calendar_date, month)                        as month_start_date,
last_day(calendar_date, month)                          as month_end_date,
extract(week from calendar_date)                        as week_number,
date_trunc(calendar_date, week)                         as week_start_date,
extract(dayofweek from calendar_date) in (1, 7)         as is_weekend
 
from date_spine
)
select *
from date_fields
