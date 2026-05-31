{{ config(
    materialized = 'table'
) }}

with date_spine as (

    select calender_date
    from unnest( generate_date_array('2024-01-01','2035-01-01')

) as calender_date ),

date_fields as (
Select 
--surrogate key created for join in YYYYMMDD format
cast(format_date('%Y%m%d',calender_date) as int64)          as date_key ,
calender_date                                              as calender_date, 
extract(year from calender_date)                            as year,
extract(quarter from calender_date)                         as quarter,
extract(month from calender_date)                           as month,
format_date('%b', calender_date)                            as month_short,
format_date('%Y-%m', calender_date)                        as year_month,
date_trunc(calender_date, month)                        as month_start_date,
last_day(calender_date, month)                          as month_end_date,
extract(week from calender_date)                        as week_number,
date_trunc(calender_date, week)                         as week_start_date,
extract(dayofweek from calender_date) in (1, 7)         as is_weekend
 
from date_spine
)
select *
from date_fields
