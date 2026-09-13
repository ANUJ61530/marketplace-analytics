-- =============================================================================
-- 02_MARKETPLACE_METRICS.SQL
-- Executive Marketplace Health & Commercial Performance KPIs (MySQL 8.0+)
-- =============================================================================
-- Granularity: Monthly Aggregations
-- Filter: Delivered orders (order_status = 'delivered') for GMV/AOV accuracy.

USE marketplace_db;

-- -----------------------------------------------------------------------------
-- 1. MONTHLY EXECUTIVE KPI SCORECARD
-- Metrics: Total Orders, Completed Orders, Total GMV, Item Subtotal, Freight,
-- AOV, Active Buyers, New Buyers, Repeat Buyers, Orders Per Buyer, MoM Growth.
-- -----------------------------------------------------------------------------

WITH monthly_orders AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        COUNT(o.order_id) AS total_orders_placed,
        COUNT(CASE WHEN o.order_status = 'delivered' THEN o.order_id END) AS completed_orders,
        COUNT(CASE WHEN o.order_status = 'canceled' THEN o.order_id END) AS canceled_orders,
        
        -- Customer Identity Tracking (Unique Consumers)
        COUNT(DISTINCT c.customer_unique_id) AS total_active_customers,
        
        -- Item-level Financials (Pre-aggregated per order to prevent duplication)
        SUM(CASE WHEN o.order_status = 'delivered' THEN oi.goods_subtotal ELSE 0 END) AS total_goods_value,
        SUM(CASE WHEN o.order_status = 'delivered' THEN oi.freight_total ELSE 0 END) AS total_freight_value,
        SUM(CASE WHEN o.order_status = 'delivered' THEN oi.order_gmv ELSE 0 END) AS total_delivered_gmv

    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    LEFT JOIN (
        SELECT 
            order_id,
            SUM(price) AS goods_subtotal,
            SUM(freight_value) AS freight_total,
            SUM(price + freight_value) AS order_gmv
        FROM fact_order_items
        GROUP BY order_id
    ) oi ON o.order_id = oi.order_id
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
),

customer_first_orders AS (
    -- Identify the birth month of every distinct customer
    SELECT
        c.customer_unique_id,
        MIN(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')) AS cohort_month
    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

monthly_customer_cohorts AS (
    -- Partition active monthly buyers into New vs Returning
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        COUNT(DISTINCT CASE 
            WHEN DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') = cfo.cohort_month 
            THEN c.customer_unique_id 
        END) AS new_customers,
        COUNT(DISTINCT CASE 
            WHEN DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') > cfo.cohort_month 
            THEN c.customer_unique_id 
        END) AS repeat_customers
    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    JOIN customer_first_orders cfo ON c.customer_unique_id = cfo.customer_unique_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
)

SELECT
    mo.order_month,
    mo.total_orders_placed,
    mo.completed_orders,
    ROUND(mo.completed_orders / NULLIF(mo.total_orders_placed, 0) * 100, 2) AS completion_rate_pct,
    mo.canceled_orders,
    
    -- Commercial Throughput (BRL)
    ROUND(mo.total_goods_value, 2)      AS total_goods_value,
    ROUND(mo.total_freight_value, 2)    AS total_freight_value,
    ROUND(mo.total_delivered_gmv, 2)    AS total_delivered_gmv,
    
    -- Average Order Value (AOV)
    ROUND(mo.total_delivered_gmv / NULLIF(mo.completed_orders, 0), 2) AS aov_gmv,
    ROUND(mo.total_goods_value / NULLIF(mo.completed_orders, 0), 2)   AS aov_basket_goods_only,
    
    -- Buyer Dynamics
    mcc.new_customers,
    mcc.repeat_customers,
    (mcc.new_customers + mcc.repeat_customers) AS active_delivered_customers,
    ROUND(mcc.repeat_customers / NULLIF((mcc.new_customers + mcc.repeat_customers), 0) * 100, 2) AS repeat_customer_share_pct,
    ROUND(mo.completed_orders / NULLIF((mcc.new_customers + mcc.repeat_customers), 0), 3) AS orders_per_customer,
    
    -- Month-over-Month (MoM) Growth Computations
    ROUND(
        (mo.total_delivered_gmv - LAG(mo.total_delivered_gmv) OVER (ORDER BY mo.order_month)) 
        / NULLIF(LAG(mo.total_delivered_gmv) OVER (ORDER BY mo.order_month), 0) * 100, 
    2) AS mom_gmv_growth_pct,
    
    ROUND(
        (mo.completed_orders - LAG(mo.completed_orders) OVER (ORDER BY mo.order_month)) 
        / NULLIF(LAG(mo.completed_orders) OVER (ORDER BY mo.order_month), 0) * 100, 
    2) AS mom_order_growth_pct

FROM monthly_orders mo
LEFT JOIN monthly_customer_cohorts mcc ON mo.order_month = mcc.order_month
ORDER BY mo.order_month ASC;


-- -----------------------------------------------------------------------------
-- 2. TOP PRODUCT CATEGORY PERFORMANCE BREAKDOWN
-- Evaluates Volume, Share of GMV, AOV, and Average Freight Burden per Category
-- -----------------------------------------------------------------------------

SELECT
    COALESCE(p.category_name_english, 'unclassified') AS category_name,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(oi.order_item_id) AS total_units_sold,
    ROUND(SUM(oi.price), 2) AS total_goods_value,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_gmv,
    
    -- Category Unit Economics
    ROUND(SUM(oi.price + oi.freight_value) / COUNT(DISTINCT oi.order_id), 2) AS category_aov,
    ROUND(SUM(oi.freight_value) / NULLIF(SUM(oi.price + oi.freight_value), 0) * 100, 2) AS freight_burden_pct,
    
    -- Platform GMV Share (%)
    ROUND(
        SUM(oi.price + oi.freight_value) / 
        SUM(SUM(oi.price + oi.freight_value)) OVER () * 100, 
    2) AS gmv_share_pct

FROM fact_order_items oi
JOIN fact_orders o ON oi.order_id = o.order_id
JOIN dim_products p ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
GROUP BY COALESCE(p.category_name_english, 'unclassified')
ORDER BY total_gmv DESC
LIMIT 20;


-- -----------------------------------------------------------------------------
-- 3. STATE-LEVEL GEOGRAPHIC PERFORMANCE
-- Volume, GMV, Customer Count, and Average Delivery Speed (Days)
-- -----------------------------------------------------------------------------

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_buyers,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_gmv,
    ROUND(SUM(oi.price + oi.freight_value) / COUNT(DISTINCT o.order_id), 2) AS state_aov,
    ROUND(
        SUM(oi.price + oi.freight_value) / 
        SUM(SUM(oi.price + oi.freight_value)) OVER () * 100, 
    2) AS state_gmv_share_pct,
    
    -- Delivery Experience Metric (Mean actual days to deliver)
    ROUND(AVG(TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_delivered_customer_date) / 24.0), 1) AS avg_delivery_days,
    ROUND(AVG(CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1.0 ELSE 0.0 END) * 100, 2) AS on_time_sla_rate_pct

FROM fact_orders o
JOIN dim_customers c ON o.customer_id = c.customer_id
JOIN fact_order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY total_gmv DESC;
