-- =============================================================================
-- 01_DATA_QUALITY.SQL
-- Comprehensive Data Integrity, Table Grain, & Hygiene Audit Suite (MySQL 8.0+)
-- =============================================================================
-- This script validates warehouse reliability before downstream KPI calculations.
-- Every test outputs: Check Name, Violations Count, Status (PASS/FAIL), Notes.

USE marketplace_db;

-- -----------------------------------------------------------------------------
-- TEST 1: PRIMARY KEY UNIQUENESS & GRAIN VALIDATION
-- Target: Assert that each primary key uniquely identifies exactly one record.
-- -----------------------------------------------------------------------------

-- 1.1 Grain Check: fact_orders must be 1 row per order_id
SELECT 
    'fact_orders Grain Validation (order_id uniqueness)' AS audit_check,
    COUNT(*) - COUNT(DISTINCT order_id) AS violation_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT order_id) THEN 'PASS' ELSE 'FAIL' END AS status,
    'Expected: 0 duplicate order_ids' AS expectation
FROM fact_orders;

-- 1.2 Grain Check: fact_order_items must be unique at (order_id, order_item_id)
SELECT 
    'fact_order_items Grain Validation' AS audit_check,
    COUNT(*) - COUNT(DISTINCT CONCAT(order_id, '-', order_item_id)) AS violation_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT CONCAT(order_id, '-', order_item_id)) THEN 'PASS' ELSE 'FAIL' END AS status,
    'Expected: 0 duplicates on composite key (order_id, order_item_id)' AS expectation
FROM fact_order_items;

-- 1.3 Grain Check: fact_order_payments must be unique at (order_id, payment_sequential)
SELECT 
    'fact_order_payments Grain Validation' AS audit_check,
    COUNT(*) - COUNT(DISTINCT CONCAT(order_id, '-', payment_sequential)) AS violation_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT CONCAT(order_id, '-', payment_sequential)) THEN 'PASS' ELSE 'FAIL' END AS status,
    'Expected: 0 duplicates on composite key (order_id, payment_sequential)' AS expectation
FROM fact_order_payments;

-- 1.4 Grain Check: dim_customers transaction token uniqueness
SELECT 
    'dim_customers Token Uniqueness (customer_id)' AS audit_check,
    COUNT(*) - COUNT(DISTINCT customer_id) AS violation_count,
    CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id) THEN 'PASS' ELSE 'FAIL' END AS status,
    'Expected: 0 duplicate customer_ids' AS expectation
FROM dim_customers;


-- -----------------------------------------------------------------------------
-- TEST 2: REFERENTIAL INTEGRITY (ORPHAN RECORD AUDIT)
-- Target: Verify that child fact tables cleanly resolve to parent dimension keys.
-- -----------------------------------------------------------------------------

-- 2.1 Orphan Orders: Orders with non-existent customer tokens
SELECT 
    'Referential Integrity: Orders -> Customers' AS audit_check,
    COUNT(o.order_id) AS violation_count,
    CASE WHEN COUNT(o.order_id) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Expected: 0 orders without a matching dim_customers record' AS expectation
FROM fact_orders o
LEFT JOIN dim_customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 2.2 Orphan Items: Order items with non-existent orders
SELECT 
    'Referential Integrity: Order Items -> Orders' AS audit_check,
    COUNT(oi.order_id) AS violation_count,
    CASE WHEN COUNT(oi.order_id) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Expected: 0 items without a matching fact_orders record' AS expectation
FROM fact_order_items oi
LEFT JOIN fact_orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 2.3 Orphan Products: Order items with catalog-missing product_id
SELECT 
    'Referential Integrity: Order Items -> Products' AS audit_check,
    COUNT(oi.product_id) AS violation_count,
    CASE WHEN COUNT(oi.product_id) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Expected: 0 items referencing unknown product_ids' AS expectation
FROM fact_order_items oi
LEFT JOIN dim_products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- 2.4 Orphan Sellers: Order items with unknown seller_id
SELECT 
    'Referential Integrity: Order Items -> Sellers' AS audit_check,
    COUNT(oi.seller_id) AS violation_count,
    CASE WHEN COUNT(oi.seller_id) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Expected: 0 items referencing unknown seller_ids' AS expectation
FROM fact_order_items oi
LEFT JOIN dim_sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


-- -----------------------------------------------------------------------------
-- TEST 3: TEMPORAL SEQUENCE INTEGRITY (CHRONOLOGICAL TIMELINE VALIDATION)
-- Target: Verify timestamps respect physical causality:
-- Purchase <= Approval <= Carrier Dispatch <= Doorstep Delivery
-- -----------------------------------------------------------------------------

SELECT 
    'Temporal Validity: Approval before Purchase' AS audit_check,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Approved timestamp must be >= Purchase timestamp' AS expectation
FROM fact_orders
WHERE order_approved_at IS NOT NULL 
  AND order_approved_at < order_purchase_timestamp;

SELECT 
    'Temporal Validity: Carrier Delivery before Purchase' AS audit_check,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Carrier handoff must be >= Purchase timestamp' AS expectation
FROM fact_orders
WHERE order_delivered_carrier_date IS NOT NULL 
  AND order_delivered_carrier_date < order_purchase_timestamp;

SELECT 
    'Temporal Validity: Customer Doorstep Delivery before Purchase' AS audit_check,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Customer delivery must be >= Purchase timestamp' AS expectation
FROM fact_orders
WHERE order_delivered_customer_date IS NOT NULL 
  AND order_delivered_customer_date < order_purchase_timestamp;

SELECT 
    'Temporal Validity: Customer Delivery before Carrier Handoff' AS audit_check,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Customer delivery must be >= Carrier dispatch date' AS expectation
FROM fact_orders
WHERE order_delivered_customer_date IS NOT NULL 
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date < order_delivered_carrier_date;


-- -----------------------------------------------------------------------------
-- TEST 4: NUMERIC SANITY & MONETARY POLARITY
-- Target: Price and payments must be strictly non-negative; Review scores between 1-5.
-- -----------------------------------------------------------------------------

-- 4.1 Negative / Zero Item Prices
SELECT 
    'Monetary Sanity: Non-positive Item Prices' AS audit_check,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Prices must be strictly > 0.00' AS expectation
FROM fact_order_items
WHERE price <= 0.00;

-- 4.2 Negative Freight Charges
SELECT 
    'Monetary Sanity: Negative Freight Value' AS audit_check,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Freight value must be >= 0.00' AS expectation
FROM fact_order_items
WHERE freight_value < 0.00;

-- 4.3 Negative / Zero Payment Settlements
SELECT 
    'Monetary Sanity: Non-positive Payment Value' AS audit_check,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Payment value must be > 0.00 (excluding 100% voucher coverage orders)' AS expectation
FROM fact_order_payments
WHERE payment_value <= 0.00;

-- 4.4 Review Score Bound Limits (1 to 5)
SELECT 
    'Survey Sanity: Review Score Bounds' AS audit_check,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    'Review score must be an integer between 1 and 5' AS expectation
FROM fact_order_reviews
WHERE review_score NOT BETWEEN 1 AND 5;


-- -----------------------------------------------------------------------------
-- TEST 5: REVENUE RECONCILIATION AUDIT (GMV vs PAYMENT TENDER RECONCILIATION)
-- Target: For delivered orders, item GMV (price + freight) should closely reconcile
-- with payment settlement value. Variance > 1.00 BRL flags potential voucher/refund leakage.
-- -----------------------------------------------------------------------------

WITH order_level_reconciliation AS (
    SELECT 
        o.order_id,
        COALESCE(SUM(oi.price + oi.freight_value), 0.00) AS calculated_gmv,
        COALESCE(p.total_payment, 0.00) AS total_settled_payment,
        ABS(COALESCE(SUM(oi.price + oi.freight_value), 0.00) - COALESCE(p.total_payment, 0.00)) AS absolute_variance
    FROM fact_orders o
    JOIN fact_order_items oi ON o.order_id = oi.order_id
    LEFT JOIN (
        SELECT order_id, SUM(payment_value) AS total_payment
        FROM fact_order_payments
        GROUP BY order_id
    ) p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, p.total_payment
)
SELECT 
    'Financial Audit: GMV to Payment Settlement Variance' AS audit_check,
    COUNT(CASE WHEN absolute_variance > 1.00 THEN 1 END) AS orders_with_discrepancy,
    ROUND(SUM(absolute_variance), 2) AS total_discrepancy_value,
    CASE WHEN COUNT(CASE WHEN absolute_variance > 1.00 THEN 1 END) / COUNT(*) < 0.01 
         THEN 'PASS (Within 1% tolerance)' 
         ELSE 'WARNING' END AS status,
    'Tolerance: Variance > 1.00 BRL on less than 1% of delivered orders' AS expectation
FROM order_level_reconciliation;


-- -----------------------------------------------------------------------------
-- TEST 6: MISSING VALUE & COMPLETENESS PROFILE
-- Target: Assess NULL presence across essential operational columns.
-- -----------------------------------------------------------------------------

SELECT 
    'Orders Completeness Profile' AS audit_check,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) AS null_status,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_purchase_time,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS null_promised_date,
    SUM(CASE WHEN order_status = 'delivered' AND order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS delivered_missing_timestamp
FROM fact_orders;
