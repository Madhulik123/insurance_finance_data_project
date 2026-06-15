-- Time spine required by MetricFlow for time-based and cumulative metrics.
-- Reuses the existing dim_date calendar spine (2024-2035, daily grain).
{{ config(materialized = 'table') }}

select
    calendar_date as date_day
from {{ ref('dim_date') }}
