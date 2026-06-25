# Insurance Analytics Case Study — Business Insights

**Author:** Madhulika Suman · **Date:** 2026-06-10
**Sources analysed:** `Raw.csv` (2,660 finance transactions), `accounting_monthly_closing.csv` (12 monthly closing figures), `product_customers.csv` (10 customer contracts — illustrative sample)
**Status:** Figures verified against the live dbt marts in BigQuery (`mart_finance_vs_accounting_cal`).

---

## Executive Summary

- The raw transaction record reconciles to the Accounting monthly closing on a **gross premium** basis — **8 of 12 party-months match to the cent**, and the total unexplained gap is only **€26.13 (~0.15% of gross)**. Correcting 3 sign-flipped charges cut this gap from an earlier €68.
- Refunds are economically material: **47 refunds totalling €302.46** separate gross (billed) premium from net (earned) premium. This is the single biggest driver of any "earned vs billed" conversation.
- The transaction data carries **minor but real quality issues** — 2 duplicate transaction IDs, ~29 failed charges, a `process`/`processed` status typo, and 3 sign-flipped (`processed` + negative) charges — all now handled in the dbt pipeline.
- The customer dataset provided is a **10-row sample**, sufficient to validate the KPI model but not to draw population-level conclusions. It does, however, expose **ID-corruption and date-integrity issues** worth fixing at source.

---

## Part I — Finance vs Accounting

### 1. Premium by party (June–August 2025, deduplicated)

| Party | Gross (Jun–Aug) | Net (Jun–Aug) | Refunds (total)* |
|-------|--------------:|------------:|----------------:|
| dronant | €5,857.97 | €5,764.61 | 13 |
| liadigital | €4,467.09 | €4,419.23 | 10 |
| getland | €3,802.78 | €3,745.38 | 12 |
| berlinre | €3,289.25 | €3,185.41 | 12 |
| **Total** | **€17,417.09** | **€17,114.63** | **47** |

> *Refund counts cover all transactions (€302.46 total).*

> **dronant** is the largest partner by premium volume (~34% of gross). Berlinre carries the **highest refund rate** relative to its premium base.

### 2. Reconciliation result (gross vs accounting)

| Outcome | Count | Notes |
|---------|------:|-------|
| Exact match (< €0.01) | 8 / 12 | getland (all 3 months), berlinre Jul & Aug, dronant-Jun, liadigital Jul & Aug |
| Small difference | 4 / 12 | Accounting slightly **higher** than finance gross in every case |

**Total absolute gap:**
- Gross vs accounting: **€26.13** (~0.15%)
- Net vs accounting: €328.59 (~1.9%)

This is the key analytical finding: **Accounting closes on gross**, so finance must report **gross premium** to reconcile. Reporting net would manufacture a €370 phantom discrepancy.

### 3. Are there discrepancies, and what causes them?

Yes — four party-months show Accounting marginally above finance gross:

| Party | Month | Gross | Accounting | Diff |
|-------|-------|------:|-----------:|-----:|
| berlinre | 2025-06 | 1,476.45 | 1,483.22 | −6.77 |
| liadigital | 2025-06 | 2,235.13 | 2,241.79 | −6.66 |
| dronant | 2025-07 | 1,773.57 | 1,780.19 | −6.62 |
| dronant | 2025-08 | 1,100.99 | 1,107.07 | −6.08 |

**Resolved:** 3 transactions were `processed` with a *negative* amount (sign-entry errors); Accounting books these as positive premium. Correcting the sign reconciled **berlinre 2025-07 to the cent** and roughly halved dronant 2025-07's gap — cutting the total from €68 to €26.13.
**Ruled out:** timezone treatment (UTC vs Europe/Berlin produces the *same* gap) and duplicate IDs (only 2 exist, already deduplicated).

**Likely remaining causes & recommended actions:**
1. **Refund / charge timing** — a charge counted by Accounting at close that was later refunded or re-stated in our system. → Agree a shared cut-off timestamp with Accounting.
2. **Failed-transaction treatment** — 29 `failed` charges are excluded from finance gross; Accounting may include some provisionally. → Confirm Accounting's treatment of failed charges.
3. **Manual accounting adjustments** — small manual entries in the closing not present in raw data. → Request a line-item breakdown for the 5 flagged cells.

The `mart_finance_vs_accounting_cal` model now produces this reconciliation automatically every run, with `match_status`, `gross_vs_accounting_diff`, and `refund_impact` columns ready for a BI alert.

---

## Part II — Customer KPIs

> The supplied `product_customers.csv` contains **10 rows** (the case-study sample). Figures below are illustrative; the model is built to scale to the full population.

### Portfolio snapshot

| Metric | Value |
|--------|------:|
| Contracts | 10 |
| Active | 7 |
| Churned | 3 (30%) |
| Total monthly premium (all) | €377.02 |
| Monthly premium (active only) | €280.63 |
| Avg monthly premium | €37.70 |
| Premium range | €0.19 – €83.10 |

### Premium & churn by product group

| Product group | Contracts | Monthly premium | Churned |
|---------------|----------:|----------------:|--------:|
| dog | 2 | €99.87 | 0 |
| car | 1 | €83.10 | 0 |
| dental | 1 | €69.92 | 1 (100%) |
| legal | 2 | €43.90 | 1 (50%) |
| contents | 1 | €42.78 | 0 |
| liability | 3 | €37.45 | 1 (33%) |

> **dog** and **car** carry the highest premium per contract; **dental** and **legal** show the highest churn in this sample (small-n caveat applies).

### Data-quality issues found in the customer source

| Issue | Example | Impact | Fix |
|-------|---------|--------|-----|
| Corrupted user IDs (Excel auto-date) | `Sep-03`, `Jun-42` | Breaks customer keys/joins | Store IDs as text at ingestion; re-export source |
| Start before acquisition | `9-918f`: started 2025-01-01, acquired 2025-11-30 | Impossible / retroactive timeline | Add a `started_at >= acquisition_date` test |
| Suspiciously low premium | `Sep-03`: €0.19 | Likely data-entry error | Add min-premium plausibility check |

---

## How the model supports these insights (reusable, not one-off)

- **`mart_monthly_premiums`** — gross & net premium per party/month → powers all Part I reporting.
- **`mart_finance_vs_accounting_cal`** — automated reconciliation with match status, diff, and refund impact → replaces manual invoice comparison.
- **`fact_customers_daily`** — one row per customer per active day, with **prorated `daily_premium`** (monthly ÷ days-in-month) and **pre-computed `accumulated_acquired_premium`** → BI tool needs only `SUM`/`COUNT`.
- **Scalability:** `fact_customers_daily` is clustered by product group & user; a full rebuild correctly handles **retroactive cancellations/refunds**. *(Date partitioning is the production default; it's disabled on the current BigQuery sandbox, where partitions auto-expire after 60 days and would delete history.)*

---

## Recommended next steps

1. **Adopt gross premium as the reconciliation standard** with Accounting and document it.
2. **Investigate the 5 flagged party-months** (€68 total) with Accounting line items; set a BI alert when `match_status = 'Difference'`.
3. **Track refund rate** (€302 / 0.4% of gross) as a monitored KPI by partner — berlinre is the current outlier.
4. **Fix customer-source data quality** (text IDs, date-integrity tests) before scaling the KPI mart to production.
