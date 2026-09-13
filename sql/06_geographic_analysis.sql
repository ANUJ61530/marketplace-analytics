-- =============================================================================
-- 06_GEOGRAPHIC_ANALYSIS.SQL
-- Spatial, Category Elasticity & Seller Reliability Deep-Dive (MySQL 8.0+)
-- =============================================================================
-- Focus: Identifying geographic concentration, category basket archetypes,
-- and seller operational reliability with minimum order volume controls.

USE marketplace_db;

-- -----------------------------------------------------------------------------
-- 1. GEOGRAPHIC CONCENTRATION & LOGISTICS EFFICIENCY
-- Ranks Brazilian States by GMV, Margin/Freight Burden, and Delivery SLA Latency
-- -----------------------------------------------------------------------------

WITH state_metrics AS (
    SELECT
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT c.customer_unique_id) AS unique_buyers,
        SUM(oi.price) AS total_product_spend,
        SUM(oi.freight_value) AS total_freight_spend,
        SUM(oi.price + oi.freight_value) AS total_gmv,
        
        -- Logistics Experience
        AVG(TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_delivered_customer_date) / 24.0) AS avg_delivery_days,
        AVG(TIMESTAMPDIFF(HOUR, o.order_estimated_delivery_date, o.order_delivered_customer_date) / 24.0) AS avg_delay_vs_sla_days,
        AVG(CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1.0 ELSE 0.0 END) * 100 AS on_time_rate_pct,
        
        -- Customer Satisfaction (CSAT Proxy)
        AVG(r.review_score) AS avg_customer_rating

    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    JOIN fact_order_items oi ON o.order_id = oi.order_id
    LEFT JOIN fact_order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY c.customer_state
),

platform_totals AS (
    SELECT SUM(total_gmv) AS platform_gmv FROM state_metrics
)

SELECT
    sm.customer_state,
    sm.total_orders,
    sm.unique_buyers,
    ROUND(sm.total_gmv, 2) AS total_gmv,
    ROUND(sm.total_gmv / pt.platform_gmv * 100, 2) AS gmv_share_pct,
    ROUND(sm.total_gmv / sm.total_orders, 2) AS state_aov,
    ROUND(sm.total_freight_spend / sm.total_gmv * 100, 2) AS freight_share_of_gmv_pct,
    ROUND(sm.avg_delivery_days, 1) AS avg_delivery_lead_days,
    ROUND(sm.on_time_rate_pct, 1) AS on_time_sla_pct,
    ROUND(sm.avg_customer_rating, 2) AS avg_csat_score,
    
    -- Cumulative GMV Pareto Share
    ROUND(
        SUM(sm.total_gmv) OVER (ORDER BY sm.total_gmv DESC) / pt.platform_gmv * 100, 
    2) AS cumulative_gmv_pareto_pct

FROM state_metrics sm
CROSS JOIN platform_totals pt
ORDER BY sm.total_gmv DESC;


-- -----------------------------------------------------------------------------
-- 2. CATEGORY ARCHETYPE MATRIX: AOV VS ORDER FREQUENCY / VOLUME
-- Classifies categories into:
-- - High Ticket / Low Frequency (AOV > P75, Volume < P50)
-- - Volume Drivers / Staples (AOV < P50, Volume > P75)
-- - Core Power Categories (AOV > P50, Volume > P50)
-- -----------------------------------------------------------------------------

WITH category_stats AS (
    SELECT
        COALESCE(p.category_name_english, 'unclassified') AS category_name,
        COUNT(DISTINCT oi.order_id) AS order_volume,
        COUNT(oi.order_item_id) AS items_sold,
        SUM(oi.price + oi.freight_value) AS category_gmv,
        AVG(oi.price + oi.freight_value) AS avg_item_price,
        SUM(oi.price + oi.freight_value) / COUNT(DISTINCT oi.order_id) AS category_aov
    FROM fact_order_items oi
    JOIN fact_orders o ON oi.order_id = o.order_id
    JOIN dim_products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY COALESCE(p.category_name_english, 'unclassified')
),

benchmarks AS (
    SELECT 
        AVG(category_aov) AS benchmark_aov,
        AVG(order_volume) AS benchmark_volume
    FROM category_stats
)

SELECT
    cs.category_name,
    cs.order_volume,
    cs.items_sold,
    ROUND(cs.category_gmv, 2) AS category_gmv,
    ROUND(cs.category_aov, 2) AS category_aov,
    
    CASE 
        WHEN cs.category_aov >= b.benchmark_aov AND cs.order_volume >= b.benchmark_volume 
            THEN 'Core Power Category (High GMV, High Frequency)'
        WHEN cs.category_aov >= b.benchmark_aov AND cs.order_volume < b.benchmark_volume 
            THEN 'High-Ticket Destination (High AOV, Low Frequency)'
        WHEN cs.category_aov < b.benchmark_aov AND cs.order_volume >= b.benchmark_volume 
            THEN 'Daily Volume Engine (Low AOV, High Frequency)'
        ELSE 'Niche / Long-Tail (Low AOV, Low Frequency)'
    END AS strategic_quadrant

FROM category_stats cs
CROSS JOIN benchmarks b
ORDER BY cs.order_volume DESC
LIMIT 25;


-- -----------------------------------------------------------------------------
-- 3. SELLER QUALITY & OPERATIONAL RELIABILITY AUDIT
-- Filters for sample size: Minimum 30 lifetime fulfilled orders to eliminate low-sample bias.
-- Flags sellers with extreme cancellation rates, late shipments, or low CSAT.
-- -----------------------------------------------------------------------------

SELECT
    s.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT o.order_id) AS total_orders_assigned,
    SUM(CASE WHEN o.order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
    ROUND(SUM(CASE WHEN o.order_status = 'canceled' THEN 1 ELSE 0 END) / COUNT(DISTINCT o.order_id) * 100, 2) AS cancellation_rate_pct,
    
    -- Fulfillment Timeliness
    AVG(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1.0 ELSE 0.0 END) * 100 AS late_delivery_rate_pct,
    
    -- Customer Satisfaction
    ROUND(AVG(r.review_score), 2) AS avg_seller_rating,
    
    -- Financial Scale
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_seller_gmv

FROM fact_order_items oi
JOIN fact_orders o ON oi.order_id = o.order_id
JOIN dim_sellers s ON oi.seller_id = s.seller_id
LEFT JOIN fact_order_reviews r ON o.order_id = r.order_id
GROUP BY s.seller_id, s.seller_state, s.seller_city
HAVING COUNT(DISTINCT o.order_id) >= 30 -- Sample size threshold to avoid outlier ranking bias
ORDER BY cancellation_rate_pct DESC, avg_seller_rating ASC
LIMIT 20;
