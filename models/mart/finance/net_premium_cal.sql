with 

int_finance_data_cal as (

Select * from {{ ref('int_finance_data') }}
),

aggregated as (

    Select 
    party,
    transaction_month as month,
    round(sum(net_premium_amount),2) as premium,
    round(sum(case when status = 'processed' then premium_amount else 0 End),2) as gross_processes_premium,
    round(sum(case when status = 'refunded' then premium_amount else 0 End),2) as total_refunded_premium,
    count(*) as total_transaction,
    case when status = 'processed' then 1 else 0 end as processed_count,
    case when status = 'refunded' then 1 else 0 end as refunded_count,
    case when status = 'failed' then 1 else 0 as failed_count,

)

