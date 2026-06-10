{{ config(
    materialized = 'view'
) }}

with source_data as (

    select *
    from {{ source('raw', 'rawdata_getsafe') }}

),

deduplicated as (

    select *
    from source_data
    where transaction_id is not null

    qualify row_number() over (
        partition by transaction_id
        order by created_at desc
    ) = 1

),

data as (

    select 
        transaction_id,
        created_at,
        date(created_at) as created_date_utc,
        date(created_at, 'Europe/Berlin') as created_date_berlin,

        lower(trim(charged_party)) as charged_party,
        cast(premium_amount as numeric) as premium_amount,
        upper(trim(premium_currency)) as premium_currency,

        lower(trim(status)) as raw_status,

        case 
            when lower(trim(status)) = 'process' then 'processed'
            when lower(trim(status)) = 'processed' then 'processed'
            when lower(trim(status)) = 'refunded' then 'refunded'
            when lower(trim(status)) = 'failed' then 'failed'
            else 'unknown'
        end as status

    from deduplicated

)

select *
from data