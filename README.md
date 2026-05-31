# Getsafe Analytics Engineer Case Study

# Objective :
The objective of this project is to design a simple and reliable analytics layer for finance reporting.

This project focuses on:
1. Building a semantic layer for the finance team to report premium metrics consistently.
2. Identifying differences between finance and accounting data, and creating a repeatable reconciliation process.
3. Designing reporting marts that can be directly used in BI tools for KPI dashboards.
4. Creating a maintainable dbt structure that can support future reporting, performance and data quality needs.

# Lineage graph below:


# Data Model 
Finance and Customer Pipeline.This project follows a **multi-layer dbt architecture** combining **Medallion Architecture** 
and **Kimball Dimensional Modelling** principles.It specifically uses a star schema with two independant data models e.g finance and customer data models. 



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
Claude,
Word Doc
