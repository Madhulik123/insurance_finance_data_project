# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **dbt (data build tool)** analytics project for Getsafe, targeting **Google BigQuery**. It builds a finance and customer analytics layer using a multi-layer Medallion + Kimball star schema architecture.

## Common Commands

```bash
# Load seed data to BigQuery
dbt seed

# Run all models
dbt run

# Run tests
dbt test

# Run everything (seed + run + test) in one command
dbt build

# Run a single model
dbt run --select <model_name>

# Run a single model and all its upstream dependencies
dbt run --select +<model_name>

# Run tests for a single model
dbt test --select <model_name>

# Compile without running (check SQL syntax)
dbt compile
```

## Architecture

Two fully independent data pipelines share `dim_date` but are otherwise separate:

### Finance Pipeline
```
source: raw.rawdata_getsafe (Raw.csv)
  → stg_raw_financial_data          (view) — dedup, type cast, status normalization
    → int_finance_data               (view) — applies net/gross premium business rules
      → dim_party                    (table) — party dimension derived from staging
      → dim_date                     (table) — shared calendar spine 2024–2035
      → fact_transactions            (table) — one row per transaction with FK keys
        → mart_monthly_premiums      (table) — gross/net premium by party and month
        → mart_finance_vs_accounting_cal (table) — reconciliation vs accounting seed
```

### Customer Pipeline
```
source: product_customers.product_customers (product_customers.csv)
  → stg_pc_product_customers         (view) — type cast, active flag, duration
    → dim_product_group              (table) — product dimension derived from staging
    → dim_date                       (table) — shared calendar spine
    → fact_customers_daily           (table) — one row per customer per active day
        → mart_customer_kpis         (table) — BI-ready daily KPIs
```

### Key Design Decisions

- **`fact_customers_daily`** uses `generate_date_array` + `cross join unnest` to explode each customer contract into one row per active day. This allows the BI tool to use only `SUM` and `COUNT` for all KPIs (active customers, daily premium, accumulated acquired premium).
- **`accumulated_acquired_premium`** is computed via a window function (`SUM(acquired_premium) OVER ... ROWS UNBOUNDED PRECEDING`) so BI tools don't need running totals.
- **Surrogate keys** in dimension tables use `farm_fingerprint()` for stability — `row_number()` is unsafe as new rows would re-number existing keys.
- **Reconciliation** (`mart_finance_vs_accounting_cal`) compares `gross_premium_amount` from finance against the accounting seed (`accounting_monthly_closing.csv`) — the accounting closing aligns with gross (processed charges before refunds). It uses a `FULL OUTER JOIN` to surface both sides of any discrepancy, and also surfaces `net_premium_amount` and `refund_impact` alongside.

### Materialization Strategy (set in `dbt_project.yml`)
| Layer | Materialization |
|-------|----------------|
| staging | view |
| intermediate | view |
| dimensions | table |
| facts | table |
| mart | table |

### BigQuery-Specific Patterns
- `fact_customers_daily` uses `cluster_by = ['product_group_key', 'user_id']` for query performance. **Partitioning by `calendar_date` is intentionally disabled**: this project runs on a BigQuery sandbox (no billing), where partitions expire after 60 days and silently delete historical rows (which zeroed out `acquired_premium` and the cumulative metrics). Restore `partition_by = {field: 'calendar_date', granularity: 'month'}` once billing is enabled — see the comment in the model.
- `QUALIFY ROW_NUMBER()` is used in staging for deduplication.
- `date(timestamp, 'Europe/Berlin')` is used for timezone-aware date extraction.

### Semantic Layer (dbt / MetricFlow)
- `models/semantic_layer/` defines 9 metrics (simple, derived `refund_impact`, cumulative acquired premium) over the facts, plus a `metricflow_time_spine` (from `dim_date`) and dimension semantic models for slicing. Query locally with `mf query`; see `models/semantic_layer/README.md`.

## Data Sources

| Source | Description |
|--------|-------------|
| `raw.rawdata_getsafe` | Raw finance transactions: `transaction_id`, `created_at`, `premium_amount`, `premium_currency`, `charged_party`, `status` |
| `product_customers.product_customers` | Customer contracts: `user_id`, `premium`, `product_group`, `acquisition_date`, `started_at`, `churned_at` |
| `seeds/accounting_monthly_closing.csv` | Accounting team's monthly closing figures: `party`, `month` (YYYY-MM), `premium` |

## Schema & Tests

All model descriptions, column definitions, and dbt tests (`not_null`, `unique`) are in `models/schema.yml`. Sources are also declared there, pointing to database `madhulika-data-project` in BigQuery.
