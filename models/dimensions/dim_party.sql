{{ config(
    materialized = 'table'
) }}


with party as (

    Select distinct lower(trim(charged_party)) as party_key
    from {{ ref('stg_raw_financial_data') }}
)

Select 

    -- deterministic surrogate key: stable even when new parties are added
    abs(farm_fingerprint(party_key)) as party_id,
    party_key,
    initcap(replace(party_key, '_', ' ')) as party_name,

   --party type has been defined
   case 
    when party_key like '%re' then 'Reinsurer'
    when party_key like '%digital' then 'digital_partner'
    when party_key like '%land' then 'property_partner'
    else 'partner' end as party_type,
    current_timestamp() as _loaded_at

from party

