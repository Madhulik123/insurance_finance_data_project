# Semantic Layer & Data Modeling Checklist

A practical checklist for designing and building a semantic layer (data modeling +
BI-ready metrics), grounded in the patterns used in this Getsafe dbt project:
Medallion layering, Kimball star schema, grain-first facts, conformed `dim_date`,
additive measures, reconciliation, and dbt tests.

Split into **MANDATORY** (skip these and the layer is wrong or untrustworthy) and
**STRONGLY RECOMMENDED** (needed for production scale and trust).

---

## 🔴 MANDATORY — non-negotiable for any semantic layer

### 1. Define the grain of every fact — first, in writing
- [ ] State the grain as one sentence per fact table.
  - e.g. *"one row per customer contract per active day"* (`fact_customers_daily`),
    *"one row per transaction"* (`fact_transactions`).
- [ ] Confirm every measure and dimension is consistent with that grain.
- [ ] No mixed-grain facts (don't put monthly totals in a daily fact).

### 2. Separate dimensions from facts (conformed dimensions)
- [ ] Descriptive context → **dimensions** (`dim_date`, `dim_party`, `dim_product_group`).
- [ ] Measurable events → **facts**.
- [ ] **Conform** shared dimensions across pipelines — `dim_date` is the single calendar
      spine used by *both* the finance and customer pipelines. One definition, reused everywhere.

### 3. Stable surrogate keys
- [ ] Every dimension has a surrogate key generated deterministically (`farm_fingerprint()`),
      **not** `row_number()` — re-numbering on reload breaks historical joins.
- [ ] Facts reference dimensions by key (`date_key`, `product_group_id`), not raw business strings.
- [ ] Join keys are normalized (`lower(trim(...))`) so dirty source data still matches.

### 4. Classify every measure: additive / semi-additive / non-additive
- [ ] **Additive** (sums across all dimensions incl. time): `daily_premium`, `acquired_premium`,
      `active_contract_count`. The gold standard for a semantic layer.
- [ ] **Semi-additive** (sums across some dims but not time — balances/snapshots): flag explicitly.
- [ ] **Non-additive** (ratios, %): store **numerator and denominator separately**, compute the
      ratio at query time — never pre-average.
- [ ] Design so the BI tool only needs `SUM` / `COUNT`.

### 5. Handle time correctly
- [ ] Timezone-aware date extraction (`date(timestamp, 'Europe/Berlin')`) — don't let UTC drift
      shift events across day boundaries.
- [ ] Decide **inclusive vs. exclusive** boundaries for date ranges (e.g. the churn date) and document it.
- [ ] Proration / period logic is correct across partial periods and month-length differences.

### 6. Data quality tests on every model
- [ ] `unique` + `not_null` on every primary/surrogate key.
- [ ] `not_null` on all join keys and core measures.
- [ ] `relationships` (referential integrity) from fact FKs → dimension keys.
- [ ] `accepted_values` on status/category fields.
- [ ] Tests live in version control and run in CI (`dbt test` / `dbt build`).

### 7. Documentation that ships with the model
- [ ] Every model, column, and measure described in a schema file (`schema.yml`).
- [ ] Sources declared explicitly (database, schema, table).
- [ ] Business definitions stated where not obvious (e.g. "premium is a *monthly* amount",
      "earned vs. billed").

### 8. Single source of truth for each metric
- [ ] Each KPI defined **once** in the modeling layer, not redefined in every dashboard.
- [ ] Consumers (`mart_customer_kpis`) read from facts; they don't re-implement business logic.

### 9. Reconciliation / validation against a trusted source
- [ ] At least one model that proves the numbers are right against an external authority —
      `mart_finance_vs_accounting_cal` reconciles finance output against the accounting closing seed.
- [ ] Use a `FULL OUTER JOIN` so discrepancies on **either** side surface (missing rows, not just
      mismatched values).
- [ ] Define the reconciliation basis explicitly (gross vs. net premium).

---

## 🟡 STRONGLY RECOMMENDED — needed for production scale & trust

### 10. Layered architecture (Medallion)
- [ ] `staging` (clean/cast/dedup, **views**) → `intermediate` (business rules, views) →
      `dimensions`/`facts` (**tables**) → `marts` (BI-ready tables).
- [ ] Materialization strategy matches layer (views for cheap/upstream, tables for heavy/downstream).

### 11. Deduplication & idempotency at the edge
- [ ] Dedup raw data in staging (`QUALIFY ROW_NUMBER()`).
- [ ] Models are rebuildable from source with the same result every time.

### 12. Performance / cost controls
- [ ] Large facts **partitioned** on the main filter column (`calendar_date`, monthly).
- [ ] **Clustered** on high-cardinality slice columns (`product_group_key`, `user_id`).
- [ ] Pre-compute expensive window logic once (`accumulated_acquired_premium`) instead of per query.

### 13. Naming & layout conventions
- [ ] Consistent prefixes (`stg_`, `int_`, `dim_`, `fact_`, `mart_`) and folder structure.
- [ ] Consistent key suffixes (`_id`, `_key`).

### 14. Lineage & dependency management
- [ ] Use `ref()` / `source()` so lineage is explicit and DAG-ordered (no hardcoded table names).
- [ ] Metadata columns for auditability (`loaded_at`).

### 15. Slowly Changing Dimensions (if relevant)
- [ ] Decide SCD strategy per dimension (Type 1 overwrite vs. Type 2 history).
- [ ] Use `snapshots/` for dimensions that need history; keep current-state-only dims simple.

---

## Quick "is my semantic layer done?" gut check
1. Can every KPI be answered with `SUM` / `COUNT` + `GROUP BY`?
2. Is each metric defined exactly once?
3. Do the numbers reconcile to a trusted external figure?
4. Will keys survive a full reload without breaking joins?
5. Is the grain of each fact written down and respected?
6. Does `dbt build` pass all tests?

If all six are yes, the layer is trustworthy.
