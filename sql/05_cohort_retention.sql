-- =============================================================================
-- 05_COHORT_RETENTION.SQL
-- Monthly Customer Cohort Retention & Lifetime Value Evolution (MySQL 8.0+)
-- =============================================================================
-- Tracks buyer behavior indexed from their first purchase month (Month 0).
-- Outputs: Cohort Size, Retained User Count, User Retention %, and Cumulative GMV Retention.

USE marketplace_db;

-- -----------------------------------------------------------------------------
-- 1. MONTHLY USER RETENTION COHORT MATRIX
-- -----------------------------------------------------------------------------

WITH customer_cohort_birth AS (
    -- Identify the month of the first delivered order per unique customer
    SELECT
        c.customer_unique_id,
        MIN(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')) AS cohort_month,
        MIN(o.order_purchase_timestamp) AS first_order_date
    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

customer_activity_months AS (
    -- Map every subsequent delivered order to a cohort index (Month 0, 1, 2...)
    SELECT
        c.customer_unique_id,
        ccb.cohort_month,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS activity_month,
        -- Calculate relative period index in months
        (PERIOD_DIFF(
            DATE_FORMAT(o.order_purchase_timestamp, '%Y%m'),
            DATE_FORMAT(ccb.first_order_date, '%Y%m')
        )) AS month_index,
        oi.order_gmv
    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    JOIN customer_cohort_birth ccb ON c.customer_unique_id = ccb.customer_unique_id
    LEFT JOIN (
        SELECT order_id, SUM(price + freight_value) AS order_gmv
        FROM fact_order_items
        GROUP BY order_id
    ) oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
),

cohort_sizes AS (
    -- Denominator: Number of unique buyers who originated in each cohort month
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohort_birth
    GROUP BY cohort_month
),

cohort_retention_summary AS (
    SELECT
        cam.cohort_month,
        cs.cohort_size,
        cam.month_index,
        COUNT(DISTINCT cam.customer_unique_id) AS active_retained_users,
        SUM(cam.order_gmv) AS period_retained_gmv
    FROM customer_activity_months cam
    JOIN cohort_sizes cs ON cam.cohort_month = cs.cohort_month
    WHERE cam.month_index >= 0 AND cam.month_index <= 12
    GROUP BY cam.cohort_month, cs.cohort_size, cam.month_index
)

SELECT
    crs.cohort_month,
    crs.cohort_size,
    crs.month_index,
    crs.active_retained_users,
    ROUND(crs.active_retained_users / crs.cohort_size * 100, 2) AS retention_rate_pct,
    ROUND(crs.period_retained_gmv, 2) AS period_gmv,
    ROUND(crs.period_retained_gmv / crs.cohort_size, 2) AS gmv_per_cohort_user
FROM cohort_retention_summary crs
ORDER BY crs.cohort_month ASC, crs.month_index ASC;


-- -----------------------------------------------------------------------------
-- 2. PIVOTED COHORT RETENTION HEATMAP FORMAT (Months 0 to 6)
-- Pre-formatted for executive reporting and visual heatmaps
-- -----------------------------------------------------------------------------

WITH customer_cohort_birth AS (
    SELECT
        c.customer_unique_id,
        MIN(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')) AS cohort_month,
        MIN(o.order_purchase_timestamp) AS first_order_date
    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

cohort_activity AS (
    SELECT
        c.customer_unique_id,
        ccb.cohort_month,
        PERIOD_DIFF(
            DATE_FORMAT(o.order_purchase_timestamp, '%Y%m'),
            DATE_FORMAT(ccb.first_order_date, '%Y%m')
        ) AS month_index
    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    JOIN customer_cohort_birth ccb ON c.customer_unique_id = ccb.customer_unique_id
    WHERE o.order_status = 'delivered'
),

cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohort_birth
    GROUP BY cohort_month
)

SELECT
    cs.cohort_month,
    cs.cohort_size,
    ROUND(100.0, 1) AS m0_retention_pct,
    
    ROUND(COUNT(DISTINCT CASE WHEN ca.month_index = 1 THEN ca.customer_unique_id END) 
          / cs.cohort_size * 100, 2) AS m1_retention_pct,
          
    ROUND(COUNT(DISTINCT CASE WHEN ca.month_index = 2 THEN ca.customer_unique_id END) 
          / cs.cohort_size * 100, 2) AS m2_retention_pct,
          
    ROUND(COUNT(DISTINCT CASE WHEN ca.month_index = 3 THEN ca.customer_unique_id END) 
          / cs.cohort_size * 100, 2) AS m3_retention_pct,
          
    ROUND(COUNT(DISTINCT CASE WHEN ca.month_index = 4 THEN ca.customer_unique_id END) 
          / cs.cohort_size * 100, 2) AS m4_retention_pct,
          
    ROUND(COUNT(DISTINCT CASE WHEN ca.month_index = 5 THEN ca.customer_unique_id END) 
          / cs.cohort_size * 100, 2) AS m5_retention_pct,
          
    ROUND(COUNT(DISTINCT CASE WHEN ca.month_index = 6 THEN ca.customer_unique_id END) 
          / cs.cohort_size * 100, 2) AS m6_retention_pct

FROM cohort_sizes cs
LEFT JOIN cohort_activity ca ON cs.cohort_month = ca.cohort_month
WHERE cs.cohort_month BETWEEN '2017-01' AND '2018-02'
GROUP BY cs.cohort_month, cs.cohort_size
ORDER BY cs.cohort_month ASC;
