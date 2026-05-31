{{ config ( 
    materialized = 'view'
)}}

with source_data as (
select * from {{ source('raw', 'rawdata_getsafe') }} 
),


data as (
Select 
transaction_id as id,
created_at,
lower(trim(charged_party)) as charged_party,
cast(premium_amount as numeric) as premium_amount,
upper(trim(premium_currency)) as premium_currency,

-- raw data to keep track the actual data. 
lower(trim(status)) as raw_status,

-- cleaned the  typo in the 'Status' column and created as status

case 
when lower(trim(Status)) = 'process' then 'processed'
when lower(trim(Status)) = 'processed' then 'processed'
when lower(trim(Status)) = 'refunded' then 'refunded'
when lower(trim(Status)) = 'failed' then 'failed' 
else 'unknown'
end as status,
current_timestamp () as loaded_at

from source_data 
where transaction_id is not null

)

Select * from data
