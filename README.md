# Retail SQL Analytics — Customer & Revenue Insights

End-to-end SQL analytics on a simulated UK online retailer (**Northwind Retail Co.**),
covering revenue trends, product performance, **customer cohort retention**, and
**RFM segmentation**. Built to demonstrate analytical SQL — window functions, CTEs,
and cohort logic — applied to real business questions.

> **Stack:** SQL (SQLite) · reproducible Python data generator
> **Skills shown:** window functions (`LAG`, `RANK`, `NTILE`, running totals), multi-CTE
> queries, cohort retention analysis, RFM segmentation, conditional aggregation.

---

## The scenario

Northwind Retail Co. is a fast-growing online retailer. Leadership wants to understand
four things from the transactional data alone:

1. Is revenue growing, and how seasonal is it?
2. Which products drive each category?
3. Are we *keeping* the customers we acquire?
4. Who are our most valuable customers, and who is slipping away?

The dataset spans **Jan 2023 – Dec 2025**: 6,351 customers, 15,326 orders and 35,050
order lines across six product categories.

## Dataset

A reproducible, seeded synthetic dataset (no external downloads, no licensing issues).
Patterns such as growth, Q4 seasonality and retention decay are deliberately built in,
so the analyses surface genuine, defensible findings.

```
customers (customer_id, signup_date, region, acquisition_channel)
products  (product_id, product_name, category, unit_price, unit_cost)
orders    (order_id, customer_id, order_date, status)          status: completed | returned | cancelled
order_items (order_id, product_id, quantity, unit_price, unit_cost)
```

`orders 1—* order_items`, `customers 1—* orders`, `products 1—* order_items`.

## Repository structure

```
retail-sql-analytics/
├── README.md
├── retail.db                 ← prebuilt SQLite database (open & query immediately)
├── data/                     ← source CSVs
│   ├── customers.csv
│   ├── products.csv
│   ├── orders.csv
│   └── order_items.csv
├── sql/
│   ├── 01_schema.sql         ← table definitions + indexes
│   └── 02_analysis.sql       ← the six analytical queries
└── scripts/
    ├── generate_data.py      ← rebuild the dataset from scratch (seeded)
    └── build_db.py           ← rebuild retail.db from schema + CSVs
```

## How to run

**Option A — no install (recommended for reviewers).**
Download [DB Browser for SQLite](https://sqlitebrowser.org/) (free), open `retail.db`,
go to *Execute SQL*, and paste any query from `sql/02_analysis.sql`.

**Option B — command line.**
```bash
sqlite3 retail.db < sql/02_analysis.sql
```

**Rebuild everything from source (optional):**
```bash
python3 scripts/generate_data.py   # regenerates the CSVs (seeded, deterministic)
python3 scripts/build_db.py        # rebuilds retail.db
```

---

## The analyses & what they found

### 1. Monthly revenue trend with month-on-month growth — `LAG()`
Revenue grew from **~£18.5k/month (Jan 2023)** to **~£161k/month (Dec 2025)**. The
standout signal is seasonality: November jumps **+65%, +89% and +79%** in 2023, 2024
and 2025 respectively — a textbook Black Friday / Christmas peak — followed by the
predictable January correction (e.g. **−40%** in Jan 2025).

### 2. Cumulative (year-to-date) revenue — `SUM() OVER (...)`
A running total partitioned by year, showing how each year's revenue accumulates and
how much of the annual figure lands in Q4.

### 3. Top 3 products per category — `RANK() … PARTITION BY`
Ranks products within each category by revenue. Electronics is the heaviest category
(top product alone ≈ **£135k**), while high-margin categories like Clothing and Health
& Beauty show flatter distributions across their best sellers.

### 4. Customer cohort retention *(the showpiece)* — multi-CTE + date maths
Each customer is assigned to a **signup-month cohort**, then tracked by how many months
later they reorder. The retention curve is clear and consistent across cohorts:

| Months since signup | 0 | 1 | 2 | 3 | 4 | 6 |
|---|---|---|---|---|---|---|
| Typical retention | ~90–97% | ~30% | ~22% | ~15% | ~11% | ~5% |

The sharp month-0 → month-1 drop is the single biggest retention lever — the
business loses roughly two-thirds of a cohort after the first purchase window.

### 5. RFM segmentation — `NTILE(5)`
Customers scored on **Recency, Frequency, Monetary** and bucketed into actionable
segments:

| Segment | Customers | Avg. lifetime value | Avg. orders |
|---|---|---|---|
| Champions | 988 | £685.64 | 3.6 |
| At Risk | 1,462 | £544.78 | 3.0 |
| Loyal | 1,264 | £504.09 | 2.7 |
| New / Promising | 1,025 | £175.06 | 1.2 |
| Hibernating | 1,016 | £170.69 | 1.2 |
| Needs Attention | 437 | £160.92 | 1.2 |

The **At Risk** segment is the commercial priority: high historic value (£545 avg.) but
lapsing recency — the most cost-effective group to win back.

### 6. New vs returning revenue split — first-order flag via `MIN() OVER`
Returning-customer revenue share matured from **~6%** at launch to a steady
**~55–65%**, confirming the business is no longer dependent on constant new acquisition
— a healthy sign of a maturing customer base.

---

## Notes on portability

Written for SQLite so it runs anywhere with zero setup. The patterns translate directly
to other engines, with minor syntax swaps:

- `strftime('%Y-%m', date)` → `FORMAT(date,'yyyy-MM')` / `TO_CHAR(date,'YYYY-MM')` / `DATE_FORMAT(date,'%Y-%m')`
- `JULIANDAY(a) - JULIANDAY(b)` → `DATEDIFF(day, b, a)`
- Window functions (`LAG`, `RANK`, `NTILE`, framed `SUM`) are ANSI-standard and run unchanged on SQL Server, PostgreSQL, Snowflake, Databricks SQL and BigQuery.

---

*Data is synthetic and generated purely for demonstration. No real customer data is used.*
