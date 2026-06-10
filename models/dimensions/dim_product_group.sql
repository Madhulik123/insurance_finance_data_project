{{ config(
    materialized = 'table'
) }}


with stg as (

    Select 
    distinct lower(trim(product_group)) as product_group_key
    from {{ ref('stg_pc_product_customers') }}

)

Select
abs(farm_fingerprint(product_group_key)) as product_group_id,
product_group_key,
initcap(product_group_key) as product_group_name,
case 
when product_group_key in ('dog','cat') then 'pets'
when product_group_key in ('dental') then 'health'
when product_group_key in ('car','vehicle') then 'property'
when product_group_key in ('liability','legal') then 'liability'
else 'others'
end as product_category,
current_timestamp as loaded_at

from stg


