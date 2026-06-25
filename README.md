# Insurance Analytics Engineering Case Study

> A production-style **dbt + BigQuery** analytics layer for insurance finance & customer reporting — built with a Medallion + Kimball architecture, a governed **MetricFlow semantic layer**, automated finance-vs-accounting reconciliation, and data-quality tests.

**Stack:** dbt (BigQuery) · MetricFlow Semantic Layer · Google BigQuery · Git/GitHub
**Author:** Madhulika Suman — Senior Data Analyst, Berlin

---

## 1. The problem

A finance team needs to report premium metrics **consistently**, reconcile their transaction data against the **Accounting** team's monthly closing, and expose customer KPIs to BI tools — without every dashboard re-implementing its own (slightly different) SQL.

This project delivers that as four outcomes:
1. A **semantic layer** so every tool reports the same premium numbers from one definition.
2. A **repeatable reconciliation** between finance (raw transactions) and accounting (monthly closing).
3. **BI-ready marts** that need only `SUM`/`COUNT` — no business logic in the dashboard.
4. A **maintainable dbt project** with tests, documentation, and clear lineage.

---

## 2. Architecture at a glance

Two independent pipelines (finance & customer) share one conformed `dim_date`, built in Medallion layers and modelled as a Kimball star schema, with a MetricFlow semantic layer on top.

```
                          SOURCES (BigQuery)
        raw.rawdata_insurance              product_customers.product_customers
                 │                                       │
   ┌─────────────▼─────────────┐           ┌─────────────▼─────────────┐
   │ STAGING (views)           │           │ STAGING (views)           │
   │ clean · cast · dedup      │           │ type-cast · active flag   │
   └─────────────┬─────────────┘           └─────────────┬─────────────┘
   ┌─────────────▼─────────────┐                         │
   │ INTERMEDIATE (views)      │                         │
   │ net / gross premium rules │                         │
   └─────────────┬─────────────┘                         │
   ┌─────────────▼─────────────┐           ┌─────────────▼─────────────┐
   │ DIMS + FACTS (tables)     │  dim_date │ DIMS + FACTS (tables)     │
   │ dim_party · fact_trans.   │◄────┼────►│ dim_product_group ·       │
   └─────────────┬─────────────┘  (shared) │ fact_customers_daily      │
   ┌─────────────▼─────────────┐           └─────────────┬─────────────┘
   │ MARTS (tables)            │           ┌─────────────▼─────────────┐
   │ monthly_premiums ·        │           │ mart_customer_kpis        │
   │ finance_vs_accounting_cal │           └─────────────┬─────────────┘
   └─────────────┬─────────────┘                         │
                 └───────────────┬───────────────────────┘
                  ┌──────────────▼──────────────┐
                  │ SEMANTIC LAYER (MetricFlow)  │
                  │ 9 governed metrics, one      │
                  │ definition, queried by BI    │
                  └──────────────────────────────┘
```

### Lineage — dbt models (design view)
<img width="917" height="322" alt="dbt lineage graph" src="https://github.com/user-attachments/assets/7708d3c1-ad1e-4731-92a5-999c5794a998" />

### Lineage — semantic layer
<!-- Paste your semantic-layer lineage screenshot URL between the quotes below -->
<img width="917" alt="semantic layer lineage" src="PASTE_SEMANTIC_LAYER_IMAGE_URL_HERE" />

---

## 3. Architecture decisions — *and why*

| Decision | Why | Alternative rejected |
|---|---|---|
| **Medallion + Kimball star schema** | Clear separation (clean → business rules → analytics); conformed dimensions; BI-friendly grain | One big "wide table" — unmaintainable, re-computes logic everywhere |
| **A real semantic layer (MetricFlow)** | Define each metric **once**; every BI tool returns the same number; formulas like `refund_impact = gross − net` encoded once | Metrics re-defined per dashboard → drift and disputes |
| **Reconcile on GROSS premium** | Accounting closes on **gross**; reconciling on net would manufacture a phantom ~€370 gap | Reconcile on net — produces false discrepancies |
| **`fact_customers_daily` at one-row-per-customer-per-active-day** | Lets BI use only `SUM`/`COUNT`; handles partial months & flexible date filters natively | Push date math + running totals into every dashboard |
| **Pre-computed `accumulated_acquired_premium` (window fn)** | Running totals live in the governed layer, not the BI tool | Each dashboard re-implements a window function |
| **Surrogate keys via `farm_fingerprint()`** | Deterministic & stable across reloads — keys don't renumber when rows are added | `row_number()` — unstable, breaks historical joins |
| **Materialization: views (staging/intermediate) → tables (dims/facts/marts)** | Cheap, always-fresh upstream; fast, queryable downstream | Tables everywhere (costly) or views everywhere (slow BI) |
| **Timezone-aware dates (`Europe/Berlin`)** | Premiums land in the correct reporting month at day boundaries | Raw UTC — month-boundary misallocation |
| **Partitioning disabled on `fact_customers_daily`** *(BigQuery sandbox)* | Sandbox forces 60-day partition expiration → silently deletes history. Non-partitioned table retains all rows. **Re-enable partitioning with billing.** | Keep partitioning → lose all >60-day history (incl. cumulative metrics) |

---

## 4. The semantic layer (MetricFlow)

Nine governed metrics, defined once in `models/semantic_layer/` and queryable by any tool — sliceable by party, product, status, currency, and time (incl. custom calendar attributes like weekend/week-number).

| Metric | Type | Example slice |
|---|---|---|
| `total_gross_premium`, `total_net_premium`, `transaction_count` | simple | by `party__party_type` |
| `refund_impact` (`gross − net`) | derived | by party / month |
| `active_customers`, `active_contracts`, `total_daily_premium`, `total_acquired_premium` | simple | by `product_group__product_category` |
| `cumulative_acquired_premium` | cumulative | by `metric_time__month` |

```bash
mf query --metrics total_gross_premium,refund_impact --group-by party__party_type
mf query --metrics active_customers,total_daily_premium --group-by product_group__product_category
mf query --metrics cumulative_acquired_premium --group-by metric_time__month
```
(See `models/semantic_layer/README.md` for full details.)

---

## 5. Key insights

> Full analysis in [`analyses/Business_Insights_Summary.md`](analyses/Business_Insights_Summary.md). Figures verified against the live dbt marts.

- **Reconciliation works on gross.** The raw transactions reconcile to Accounting's monthly closing on a **gross** basis — the majority of party-months match **to the cent**, with only a small (<0.5%) residual traced to accounting-side timing/adjustments. Reporting net instead would invent a ~€370 phantom gap.
- **Refunds are material.** 47 refunds (~€302) separate **billed (gross)** from **earned (net)** premium — the core of any "earned vs billed" conversation. `refund_impact` is now a first-class metric.
- **Real data-quality issues, all handled in-pipeline:** a `process`/`processed` status typo, 2 duplicate transaction IDs, ~29 failed charges, and **3 sign-flipped "processed" charges** that were deflating gross premium (fixed → a previously mismatched party-month now reconciles exactly).
- **Customer portfolio (10-row sample):** 7 active / 3 churned (30%); highest premium per contract in `dog` & `car`; churn concentrated in `dental` & `legal` (small-n caveat). Source has fixable ID-corruption and date-integrity issues.

---

## 6. Data quality & testing

Tests run on every `dbt build` (`PASS=56, WARN=1, ERROR=0`):
- **Keys:** `unique` + `not_null` on every surrogate/business key; `relationships` (referential integrity) fact → dimension.
- **Domains:** `accepted_values` on `status`, `match_status`, and the `active_contract_count = 1` flag.
- **Business invariants (singular tests):** gross premium ≥ 0, net ≤ gross, single currency, fact grain uniqueness, reconciliation grain.
- **Monitoring (warn, non-blocking):** surfaces the sign-flipped source rows so the anomaly stays visible if it grows.

---

## 7. How to run

```bash
dbt seed     # load accounting closing seed
dbt run      # build all models
dbt test     # run data tests
dbt build    # all of the above in dependency order
```

---

## 8. Tools

dbt · Google BigQuery · MetricFlow Semantic Layer · Git/GitHub

## Author

**Madhulika Suman** — Senior Data Analyst, Berlin, Germany
[LinkedIn](https://www.linkedin.com/in/madhulika-suman-857a7181)
