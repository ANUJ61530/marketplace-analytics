-- =============================================================================
-- 03_REVENUE_RCA.SQL
-- Flagship Root Cause Analysis: Mathematical Decomposition & Segment Contribution (MySQL 8.0+)
-- =============================================================================
-- SCENARIO: Management flags a ~10% MoM contraction in Monthly Delivered GMV.
-- This script isolates the exact mathematical drivers:
-- GMV = Active Customers * Order Frequency * Average Order Value (AOV)
-- and quantifies segment-level contributions across Geography, Category, and Buyer Cohorts.

USE marketplace_db;

-- -----------------------------------------------------------------------------
-- 1. BASELINE COMPARISON PERIOD SELECTION
-- Comparing Peak Operating Month (T0: 2018-04) vs Contraction Month (T1: 2018-05 / Simulated T1)
-- -----------------------------------------------------------------------------

SET @month_t0 = '2018-04';
SET @month_t1 = '2018-05';

-- -----------------------------------------------------------------------------
-- 2. MECE THREE-FACTOR MATHEMATICAL REVENUE DECOMPOSITION
-- GMV = Users * (Orders/User) * (GMV/Order)
-- Change in GMV = User Volume Effect + Frequency Effect + AOV Effect
-- -----------------------------------------------------------------------------

WITH period_aggregates AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS period,
        COUNT(DISTINCT c.customer_unique_id) AS active_users,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT o.order_id) / COUNT(DISTINCT c.customer_unique_id) AS order_frequency,
        SUM(oi.price + oi.freight_value) AS total_gmv,
        SUM(oi.price + oi.freight_value) / COUNT(DISTINCT o.order_id) AS aov
    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    JOIN fact_order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') IN (@month_t0, @month_t1)
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
),

decomposition_matrix AS (
    SELECT
        MAX(CASE WHEN period = @month_t0 THEN active_users END)   AS u0,
        MAX(CASE WHEN period = @month_t1 THEN active_users END)   AS u1,
        MAX(CASE WHEN period = @month_t0 THEN order_frequency END) AS f0,
        MAX(CASE WHEN period = @month_t1 THEN order_frequency END) AS f1,
        MAX(CASE WHEN period = @month_t0 THEN aov END)             AS aov0,
        MAX(CASE WHEN period = @month_t1 THEN aov END)             AS aov1,
        MAX(CASE WHEN period = @month_t0 THEN total_gmv END)       AS gmv0,
        MAX(CASE WHEN period = @month_t1 THEN total_gmv END)       AS gmv1
    FROM period_aggregates
)

SELECT
    @month_t0 AS base_period_t0,
    @month_t1 AS evaluation_period_t1,
    ROUND(gmv0, 2) AS gmv_t0,
    ROUND(gmv1, 2) AS gmv_t1,
    ROUND(gmv1 - gmv0, 2) AS total_gmv_variance,
    ROUND((gmv1 - gmv0) / gmv0 * 100, 2) AS gmv_growth_pct,
    
    -- Underlying Core Drivers
    ROUND(u1 - u0, 0) AS change_in_active_users,
    ROUND((u1 - u0) / u0 * 100, 2) AS user_growth_pct,
    ROUND(f1 - f0, 4) AS change_in_frequency,
    ROUND((f1 - f0) / f0 * 100, 2) AS frequency_growth_pct,
    ROUND(aov1 - aov0, 2) AS change_in_aov,
    ROUND((aov1 - aov0) / aov0 * 100, 2) AS aov_growth_pct,
    
    -- MECE Factor Decomposition (Exact Mathematical Bridge)
    -- Factor 1: Volume Effect = (U1 - U0) * F0 * AOV0
    ROUND((u1 - u0) * f0 * aov0, 2) AS user_volume_effect_gmv,
    
    -- Factor 2: Frequency Effect = U1 * (F1 - F0) * AOV0
    ROUND(u1 * (f1 - f0) * aov0, 2) AS frequency_effect_gmv,
    
    -- Factor 3: AOV Effect = U1 * F1 * (AOV1 - AOV0)
    ROUND(u1 * f1 * (aov1 - aov0), 2) AS aov_effect_gmv,
    
    -- Reconciliation Check: Sum of effects must equal total GMV variance
    ROUND(
        ((u1 - u0) * f0 * aov0) + 
        (u1 * (f1 - f0) * aov0) + 
        (u1 * f1 * (aov1 - aov0)) - (gmv1 - gmv0), 
    2) AS reconciliation_error_tolerance

FROM decomposition_matrix;


-- -----------------------------------------------------------------------------
-- 3. NEW VS REPEAT BUYER DECOMPOSITION
-- Isolates whether the GMV shift is driven by acquisition top-of-funnel or retention
-- -----------------------------------------------------------------------------

WITH customer_first_purchase AS (
    SELECT 
        c.customer_unique_id,
        MIN(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')) AS cohort_month
    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

buyer_type_breakdown AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS period,
        CASE 
            WHEN DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') = cfp.cohort_month THEN 'New Customer'
            ELSE 'Repeat Customer' 
        END AS buyer_type,
        COUNT(DISTINCT c.customer_unique_id) AS distinct_buyers,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(oi.price + oi.freight_value) AS period_gmv,
        SUM(oi.price + oi.freight_value) / COUNT(DISTINCT o.order_id) AS buyer_type_aov
    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    JOIN fact_order_items oi ON o.order_id = oi.order_id
    JOIN customer_first_purchase cfp ON c.customer_unique_id = cfp.customer_unique_id
    WHERE o.order_status = 'delivered'
      AND DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') IN (@month_t0, @month_t1)
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'), 2
)

SELECT
    buyer_type,
    MAX(CASE WHEN period = @month_t0 THEN distinct_buyers END)  AS buyers_t0,
    MAX(CASE WHEN period = @month_t1 THEN distinct_buyers END)  AS buyers_t1,
    MAX(CASE WHEN period = @month_t0 THEN period_gmv END)       AS gmv_t0,
    MAX(CASE WHEN period = @month_t1 THEN period_gmv END)       AS gmv_t1,
    ROUND(
        MAX(CASE WHEN period = @month_t1 THEN period_gmv END) - 
        MAX(CASE WHEN period = @month_t0 THEN period_gmv END), 
    2) AS gmv_diff,
    ROUND(
        (MAX(CASE WHEN period = @month_t1 THEN period_gmv END) - 
         MAX(CASE WHEN period = @month_t0 THEN period_gmv END)) / 
        MAX(CASE WHEN period = @month_t0 THEN period_gmv END) * 100, 
    2) AS gmv_growth_pct,
    ROUND(MAX(CASE WHEN period = @month_t0 THEN buyer_type_aov END), 2) AS aov_t0,
    ROUND(MAX(CASE WHEN period = @month_t1 THEN buyer_type_aov END), 2) AS aov_t1
FROM buyer_type_breakdown
GROUP BY buyer_type;


-- -----------------------------------------------------------------------------
-- 4. GEOGRAPHIC REGION CONTRIBUTION ANALYSIS
-- Quantifies each State's absolute and percentage contribution to overall GMV change
-- Contribution % = (GMV_t1 - GMV_t0) / Total_GMV_t0
-- -----------------------------------------------------------------------------

WITH state_gmv AS (
    SELECT
        c.customer_state,
        SUM(CASE WHEN DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') = @month_t0 
                 THEN (oi.price + oi.freight_value) ELSE 0 END) AS gmv_t0,
        SUM(CASE WHEN DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') = @month_t1 
                 THEN (oi.price + oi.freight_value) ELSE 0 END) AS gmv_t1,
        COUNT(DISTINCT CASE WHEN DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') = @month_t0 
                            THEN o.order_id END) AS orders_t0,
        COUNT(DISTINCT CASE WHEN DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') = @month_t1 
                            THEN o.order_id END) AS orders_t1
    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    JOIN fact_order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') IN (@month_t0, @month_t1)
    GROUP BY c.customer_state
),

total_benchmark AS (
    SELECT 
        SUM(gmv_t0) AS total_platform_gmv_t0,
        SUM(gmv_t1) AS total_platform_gmv_t1
    FROM state_gmv
)

SELECT
    s.customer_state,
    ROUND(s.gmv_t0, 2) AS gmv_t0,
    ROUND(s.gmv_t1, 2) AS gmv_t1,
    ROUND(s.gmv_t1 - s.gmv_t0, 2) AS delta_gmv,
    ROUND((s.gmv_t1 - s.gmv_t0) / NULLIF(s.gmv_t0, 0) * 100, 2) AS state_growth_pct,
    
    -- Contribution to Total Marketplace Change (in Percentage Points)
    ROUND((s.gmv_t1 - s.gmv_t0) / NULLIF(b.total_platform_gmv_t0, 0) * 100, 3) AS contribution_to_total_growth_pp,
    
    -- Delivery Volume Dynamics
    s.orders_t0,
    s.orders_t1,
    ROUND(s.gmv_t0 / NULLIF(s.orders_t0, 0), 2) AS aov_t0,
    ROUND(s.gmv_t1 / NULLIF(s.orders_t1, 0), 2) AS aov_t1

FROM state_gmv s
CROSS JOIN total_benchmark b
ORDER BY delta_gmv ASC -- Order by largest drag on GMV first
LIMIT 15;


-- -----------------------------------------------------------------------------
-- 5. CATEGORY MIX CONTRIBUTION ANALYSIS
-- Identifies whether the decline is concentrated in high-ticket discretionary
-- or staple frequent categories
-- -----------------------------------------------------------------------------

WITH category_gmv AS (
    SELECT
        COALESCE(p.category_name_english, 'unclassified') AS category_name,
        SUM(CASE WHEN DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') = @month_t0 
                 THEN (oi.price + oi.freight_value) ELSE 0 END) AS gmv_t0,
        SUM(CASE WHEN DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') = @month_t1 
                 THEN (oi.price + oi.freight_value) ELSE 0 END) AS gmv_t1
    FROM fact_orders o
    JOIN fact_order_items oi ON o.order_id = oi.order_id
    JOIN dim_products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
      AND DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') IN (@month_t0, @month_t1)
    GROUP BY COALESCE(p.category_name_english, 'unclassified')
),

total_cat_benchmark AS (
    SELECT 
        SUM(gmv_t0) AS total_cat_gmv_t0,
        SUM(gmv_t1) AS total_cat_gmv_t1
    FROM category_gmv
)

SELECT
    c.category_name,
    ROUND(c.gmv_t0, 2) AS gmv_t0,
    ROUND(c.gmv_t1, 2) AS gmv_t1,
    ROUND(c.gmv_t1 - c.gmv_t0, 2) AS delta_gmv,
    ROUND((c.gmv_t1 - c.gmv_t0) / NULLIF(c.gmv_t0, 0) * 100, 2) AS category_growth_pct,
    ROUND((c.gmv_t1 - c.gmv_t0) / NULLIF(b.total_cat_gmv_t0, 0) * 100, 3) AS contribution_to_total_growth_pp
FROM category_gmv c
CROSS JOIN total_cat_benchmark b
ORDER BY delta_gmv ASC
LIMIT 15;
