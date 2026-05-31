{{ config(
    materialized = 'table'
) }}

with status_mapping as (

    select 'processed' as status_key, 'Processed' as status_label, 'revenue' as status_category, 1 as revenue_multiplier, true as is_successful
    union all
    select 'refunded', 'Refunded', 'refund', -1, true
    union all
    select 'failed', 'Failed', 'failed', 0, false
    union all
    select 'unknown', 'Unknown', 'unknown', 0, false

)

select *
from status_mapping