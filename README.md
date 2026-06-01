# Getsafe Analytics Engineer Case Study

# Objective :
The objective of this project is to design a simple and reliable analytics layer for finance reporting.

This project focuses on:
1. Building a semantic layer for the finance team to report premium metrics consistently.
2. Identifying differences between finance and accounting data, and creating a repeatable reconciliation process.
3. Designing reporting marts that can be directly used in BI tools for KPI dashboards.
4. Creating a maintainable dbt structure that can support future reporting, performance and data quality needs.

# Lineage graph below:
<img width="917" height="322" alt="image" src="https://github.com/user-attachments/assets/7708d3c1-ad1e-4731-92a5-999c5794a998" />


# Data Model 
Finance and Customer Pipeline.This project follows a **multi-layer dbt architecture** combining **Medallion Architecture** 
and **Kimball Dimensional Modelling** principles.It specifically uses a star schema with two independant data models e.g finance and customer data models. 

### Finance pipeline

raw.rawdata_getsafe
    └── stg_raw_finance_data
            └── dim_party ──────────────────────────┐
            └── int_finance_data ───────────────────┤
            └── dim_date (shared) ──────────────────┤
                                                    ▼
                                          fact_transactions
                                                    │
                                          ┌─────────┴──────────┐
                                          ▼                     ▼
                               mart_monthly_premiums    mart_finance_vs_accounting_cal
                                                                ▲
                                               accounting_monthly_closing

  ### Customer pipeline

product_customers.product_customers
    └── stg_pc_product_customers
            └── dim_product_group ──────────────────┐
            └── dim_date (shared) ──────────────────┤
                                                    ▼
                                        fact_customers_daily
                                                    │
                                                    ▼
                                          mart_customer_kpis



# How to run 
1. Load accounting seed data to BigQuery -
dbt seed

2. Run all models -
dbt run

3. Run tests -
dbt test

4. Run everything in one command -
dbt build

# Tools used 
DBT,
Big Query,
Github,
AI,
Word Doc

## Author

**Madhulika Suman**
Senior Data Analyst — Berlin, Germany
[LinkedIn](https://www.linkedin.com/in/madhulika-suman)
