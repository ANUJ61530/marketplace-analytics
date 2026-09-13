-- =============================================================================
-- 04_CUSTOMER_SEGMENTATION.SQL
-- RFM (Recency, Frequency, Monetary) Customer Segmentation Suite (MySQL 8.0+)
-- =============================================================================
-- Methodology:
-- 1. Snapshot Reference Date: MAX(order_purchase_timestamp) across the warehouse
-- 2. Recency (R): Days since last delivered order (Lower days = Better = Higher score)
-- 3. Frequency (F): Lifetime count of delivered orders
-- 4. Monetary (M): Lifetime Gross Merchandise Value (BRL)
-- 5. Scoring: Quintiles (1-5) via NTILE(5) for R and M.
--    Because marketplace order distribution is heavily 1-order skewed (~97%),
--    Frequency is scored via discrete business tiers to avoid artificial quantile distortion.

USE marketplace_db;

-- -----------------------------------------------------------------------------
-- 1. BASE RFM COMPUTATION PER UNIQUE CUSTOMER
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS rfm_customer_scores;
CREATE TABLE rfm_customer_scores AS
WITH snapshot_ref AS (
    SELECT MAX(order_purchase_timestamp) AS max_date
    FROM fact_orders
    WHERE order_status = 'delivered'
),

customer_summary AS (
    SELECT
        c.customer_unique_id,
        DATEDIFF((SELECT max_date FROM snapshot_ref), MAX(o.order_purchase_timestamp)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency_orders,
        SUM(oi.price + oi.freight_value) AS monetary_gmv,
        MIN(o.order_purchase_timestamp) AS first_order_date,
        MAX(o.order_purchase_timestamp) AS last_order_date
    FROM fact_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    JOIN fact_order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

rfm_quantiles AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency_orders,
        monetary_gmv,
        first_order_date,
        last_order_date,
        
        -- Recency: Inverted quintile (1 = most dormant, 5 = most recent)
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        
        -- Frequency: Discrete tier scoring (accounting for low repeat frequency)
        CASE 
            WHEN frequency_orders >= 4 THEN 5
            WHEN frequency_orders = 3 THEN 4
            WHEN frequency_orders = 2 THEN 3
            ELSE 1 
        END AS f_score,
        
        -- Monetary: Standard quintile (1 = lowest spenders, 5 = highest spenders)
        NTILE(5) OVER (ORDER BY monetary_gmv ASC) AS m_score

    FROM customer_summary
)

SELECT
    customer_unique_id,
    recency_days,
    frequency_orders,
    ROUND(monetary_gmv, 2) AS monetary_gmv,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_combined,
    
    -- Semantic Segment Assignment
    CASE
        -- Top tier active loyalists
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        
        -- High spending, good recency, moderate frequency
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        
        -- High spenders whose recency is slipping (60-150 days)
        WHEN r_score IN (2, 3) AND m_score >= 4 THEN 'At-Risk High-Value'
        
        -- Recent buyers with only 1 purchase
        WHEN r_score >= 4 AND f_score = 1 THEN 'Promising New Buyers'
        
        -- Average spenders, recent activity, single purchase
        WHEN r_score = 3 AND f_score = 1 THEN 'Needs Attention'
        
        -- Low recency, previously repeated or high spend
        WHEN r_score <= 2 AND (f_score >= 3 OR m_score >= 4) THEN 'Hibernating High-Value'
        
        -- Low recency, low monetary, single order
        WHEN r_score = 1 AND f_score = 1 AND m_score <= 2 THEN 'Lost Low-Value'
        
        ELSE 'General Dormant'
    END AS customer_segment

FROM rfm_quantiles;

-- Add index for aggregation performance
ALTER TABLE rfm_customer_scores ADD INDEX idx_cust_seg (customer_segment);


-- -----------------------------------------------------------------------------
-- 2. SEGMENT PROFILE & COMMERCIAL CONTRIBUTION SUMMARY
-- Answers: "Which segment should receive a retention intervention first, and why?"
-- -----------------------------------------------------------------------------

SELECT
    customer_segment,
    COUNT(customer_unique_id) AS customer_count,
    
    -- Customer Population Share
    ROUND(COUNT(customer_unique_id) / SUM(COUNT(customer_unique_id)) OVER () * 100, 2) AS customer_share_pct,
    
    -- Monetary Contribution
    ROUND(SUM(monetary_gmv), 2) AS total_segment_gmv,
    ROUND(SUM(monetary_gmv) / SUM(SUM(monetary_gmv)) OVER () * 100, 2) AS gmv_share_pct,
    
    -- Behavioral Benchmarks
    ROUND(AVG(recency_days), 1)     AS avg_recency_days,
    ROUND(AVG(frequency_orders), 2) AS avg_frequency_orders,
    ROUND(AVG(monetary_gmv), 2)     AS avg_monetary_gmv,
    ROUND(SUM(monetary_gmv) / SUM(frequency_orders), 2) AS segment_aov

FROM rfm_customer_scores
GROUP BY customer_segment
ORDER BY total_segment_gmv DESC;


-- -----------------------------------------------------------------------------
-- 3. INTERVENTION PRIORITY RANKING MATRIX
-- Quantifies why 'At-Risk High-Value' is the #1 Retention Priority:
-- Highest salvageable revenue per user with actionable reactivation potential.
-- -----------------------------------------------------------------------------

SELECT
    customer_segment,
    COUNT(customer_unique_id) AS segment_size,
    ROUND(SUM(monetary_gmv), 2) AS historical_gmv_at_stake,
    ROUND(AVG(monetary_gmv), 2) AS gmv_per_user,
    ROUND(AVG(recency_days), 0) AS avg_days_since_last_order,
    CASE customer_segment
        WHEN 'At-Risk High-Value' THEN 'PRIORITY 1 (Highest ROI: High Historical Value slipping into Dormancy)'
        WHEN 'Promising New Buyers' THEN 'PRIORITY 2 (Onboarding Nudge: Convert 1st order to 2nd order within 30d)'
        WHEN 'Loyal Customers' THEN 'PRIORITY 3 (Nurture & Protect: Loyalty perks, early access)'
        WHEN 'Champions' THEN 'PRIORITY 4 (Advocacy & Organic Referral)'
        ELSE 'LOW PRIORITY (Unprofitable to heavily discount)'
    END AS retention_intervention_recommendation
FROM rfm_customer_scores
GROUP BY customer_segment
ORDER BY historical_gmv_at_stake DESC;
