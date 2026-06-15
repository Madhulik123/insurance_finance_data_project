# Semantic Layer (dbt / MetricFlow)

Defines business metrics **once** on top of the star schema so every tool returns the same number.

## Files
| File | Purpose |
|------|---------|
| `metricflow_time_spine.sql` + `_time_spine.yml` | Daily date spine (from `dim_date`) — required for time-grain & cumulative metrics |
| `semantic_models.yml` | 4 semantic models: `transactions`, `customers_daily` (facts, with measures) + `party`, `product_group` (dims, for slicing) |
| `metrics.yml` | 9 metrics (simple, derived, cumulative) |

## Metrics
| Metric | Type | Sliceable by |
|--------|------|--------------|
| `total_gross_premium` | simple | party (name/type), status, currency, time |
| `total_net_premium` | simple | party, status, currency, time |
| `transaction_count` | simple | party, status, currency, time |
| `refund_impact` | derived (`gross − net`) | party, status, currency, time |
| `active_customers` | simple (count distinct) | product (category/name), is_active, time |
| `active_contracts` | simple | product, is_active, time |
| `total_daily_premium` | simple | product, is_active, time |
| `total_acquired_premium` | simple | product, is_active, time |
| `cumulative_acquired_premium` | cumulative | product, is_active, time |

## Querying locally (dbt Core + MetricFlow CLI)
On Windows, set these env vars first (otherwise `mf` errors on profile/manifest parsing):
```
$env:DBT_PROFILES_DIR="C:\Users\<you>\.dbt"
$env:PYTHONUTF8="1"; $env:PYTHONIOENCODING="utf-8"
```
Then:
```
mf list metrics
mf query --metrics total_gross_premium,total_net_premium,refund_impact --group-by party__party_type
mf query --metrics active_customers,total_daily_premium --group-by product_group__product_category
mf query --metrics total_gross_premium,cumulative_acquired_premium --group-by metric_time__month
```
Join syntax: `<entity>__<dimension>` (e.g. `party__party_type`). The shared entity names on the
fact and dimension semantic models let MetricFlow join automatically — no hand-written SQL.

## Note on `fact_customers_daily` partitioning
Partitioning by `calendar_date` is disabled on the BigQuery **sandbox** (no billing), where
partitions expire after 60 days and silently delete history. Restore it when billing is enabled —
see the comment in `models/facts/fact_customers_daily.sql`.
