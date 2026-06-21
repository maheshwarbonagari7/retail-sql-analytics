-- ============================================================
-- 02_analysis.sql
-- Business questions answered with analytical SQL.
-- Written for SQLite; notes added where ANSI / other engines differ.
-- Each query is self-contained and can be run on its own.
-- ============================================================


-- ------------------------------------------------------------
-- Q1. Monthly revenue trend with month-on-month growth
-- Technique: aggregation + LAG() window function
-- Business question: Is revenue growing, and how fast?
-- Note: net revenue excludes cancelled/returned orders.
-- ------------------------------------------------------------
WITH monthly AS (
    SELECT
        strftime('%Y-%m', o.order_date)              AS order_month,
        SUM(oi.quantity * oi.unit_price)             AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY 1
)
SELECT
    order_month,
    ROUND(revenue, 2)                                              AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY order_month), 2)            AS prev_month,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
          / LAG(revenue) OVER (ORDER BY order_month), 1)          AS mom_growth_pct
FROM monthly
ORDER BY order_month;


-- ------------------------------------------------------------
-- Q2. Running cumulative revenue (year to date style)
-- Technique: SUM() OVER (... ROWS UNBOUNDED PRECEDING)
-- Business question: What does the cumulative revenue curve look like?
-- ------------------------------------------------------------
WITH monthly AS (
    SELECT
        strftime('%Y',    o.order_date)              AS yr,
        strftime('%Y-%m', o.order_date)              AS order_month,
        SUM(oi.quantity * oi.unit_price)             AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY 1, 2
)
SELECT
    order_month,
    ROUND(revenue, 2)                                              AS revenue,
    ROUND(SUM(revenue) OVER (PARTITION BY yr ORDER BY order_month
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS ytd_revenue
FROM monthly
ORDER BY order_month;


-- ------------------------------------------------------------
-- Q3. Top 3 products by revenue within each category
-- Technique: RANK() with PARTITION BY
-- Business question: What are the best sellers in each category?
-- ------------------------------------------------------------
WITH product_rev AS (
    SELECT
        p.category,
        p.product_name,
        SUM(oi.quantity * oi.unit_price)             AS revenue,
        SUM(oi.quantity)                             AS units_sold
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    JOIN orders   o ON o.order_id   = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY p.category, p.product_name
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rev_rank
    FROM product_rev
)
SELECT category, product_name,
       ROUND(revenue, 2) AS revenue, units_sold, rev_rank
FROM ranked
WHERE rev_rank <= 3
ORDER BY category, rev_rank;


-- ------------------------------------------------------------
-- Q4. Customer cohort retention  (THE SHOWPIECE)
-- Technique: cohort defined by signup month; retention measured by
--            months elapsed between signup and each order month.
-- Business question: What share of each signup cohort is still
--            ordering N months later?
-- ------------------------------------------------------------
WITH cohort AS (
    SELECT
        customer_id,
        strftime('%Y-%m', signup_date) AS cohort_month
    FROM customers
),
activity AS (
    SELECT DISTINCT
        c.cohort_month,
        o.customer_id,
        -- whole months between signup and order
        (strftime('%Y', o.order_date) - substr(c.cohort_month, 1, 4)) * 12
        + (strftime('%m', o.order_date) - substr(c.cohort_month, 6, 2)) AS month_number
    FROM orders o
    JOIN cohort c ON c.customer_id = o.customer_id
    WHERE o.status = 'completed'
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS total_customers
    FROM cohort GROUP BY cohort_month
)
SELECT
    a.cohort_month,
    s.total_customers,
    a.month_number,
    COUNT(DISTINCT a.customer_id)                                   AS active_customers,
    ROUND(100.0 * COUNT(DISTINCT a.customer_id) / s.total_customers, 1) AS retention_pct
FROM activity a
JOIN cohort_size s ON s.cohort_month = a.cohort_month
WHERE a.month_number BETWEEN 0 AND 6
GROUP BY a.cohort_month, a.month_number, s.total_customers
ORDER BY a.cohort_month, a.month_number;


-- ------------------------------------------------------------
-- Q5. RFM segmentation
-- Technique: NTILE(5) over Recency, Frequency, Monetary
-- Business question: Who are our best customers, and who is at risk?
-- Reference "today" = day after the last order in the dataset.
-- ------------------------------------------------------------
WITH bounds AS (
    SELECT DATE(MAX(order_date), '+1 day') AS as_of FROM orders
),
customer_stats AS (
    SELECT
        o.customer_id,
        JULIANDAY((SELECT as_of FROM bounds)) - JULIANDAY(MAX(o.order_date)) AS recency_days,
        COUNT(DISTINCT o.order_id)                          AS frequency,
        SUM(oi.quantity * oi.unit_price)                    AS monetary
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY o.customer_id
),
scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,  -- lower recency = better
        NTILE(5) OVER (ORDER BY frequency)         AS f_score,
        NTILE(5) OVER (ORDER BY monetary)          AS m_score
    FROM customer_stats
)
SELECT
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
        ELSE 'Needs Attention'
    END                                            AS segment,
    COUNT(*)                                        AS customers,
    ROUND(AVG(monetary), 2)                         AS avg_lifetime_value,
    ROUND(AVG(frequency), 1)                        AS avg_orders
FROM scored
GROUP BY segment
ORDER BY avg_lifetime_value DESC;


-- ------------------------------------------------------------
-- Q6. New vs returning revenue split by month
-- Technique: first-order flag via window MIN(), conditional aggregation
-- Business question: How much revenue comes from new vs repeat custom?
-- ------------------------------------------------------------
WITH order_rev AS (
    SELECT
        o.order_id, o.customer_id, o.order_date,
        SUM(oi.quantity * oi.unit_price) AS order_value
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY o.order_id, o.customer_id, o.order_date
),
flagged AS (
    SELECT *,
        CASE WHEN order_date = MIN(order_date)
                  OVER (PARTITION BY customer_id) THEN 'New' ELSE 'Returning' END AS cust_type
    FROM order_rev
)
SELECT
    strftime('%Y-%m', order_date)                                AS order_month,
    ROUND(SUM(CASE WHEN cust_type='New'       THEN order_value END), 2) AS new_revenue,
    ROUND(SUM(CASE WHEN cust_type='Returning' THEN order_value END), 2) AS returning_revenue,
    ROUND(100.0 * SUM(CASE WHEN cust_type='Returning' THEN order_value END)
          / SUM(order_value), 1)                                 AS returning_share_pct
FROM flagged
GROUP BY order_month
ORDER BY order_month;
