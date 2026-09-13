-- =============================================================================
-- 00_SCHEMA_SETUP.SQL
-- Database Schema Definition & Staging Table Architecture (MySQL 8.0+)
-- Food Delivery Marketplace Intelligence & Analytics Platform
-- =============================================================================

CREATE DATABASE IF NOT EXISTS marketplace_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE marketplace_db;

-- -----------------------------------------------------------------------------
-- 1. DIMENSION TABLES
-- -----------------------------------------------------------------------------

-- MASTER CUSTOMERS (Entity Grain: Unique Buyer Identity)
DROP TABLE IF EXISTS dim_customers;
CREATE TABLE dim_customers (
    customer_unique_id          VARCHAR(36)     NOT NULL,
    customer_id                 VARCHAR(36)     NOT NULL, -- Order-level transaction token
    customer_zip_code_prefix    VARCHAR(10)     NOT NULL,
    customer_city               VARCHAR(100)    NOT NULL,
    customer_state              VARCHAR(2)      NOT NULL,
    first_order_timestamp       DATETIME        NULL,
    cohort_month                VARCHAR(7)      NULL, -- Formatted as 'YYYY-MM'
    PRIMARY KEY (customer_id),
    INDEX idx_cust_unique (customer_unique_id),
    INDEX idx_cust_state (customer_state),
    INDEX idx_cust_cohort (cohort_month)
) ENGINE=InnoDB;

-- PRODUCT CATALOG (Entity Grain: Unique SKU)
DROP TABLE IF EXISTS dim_products;
CREATE TABLE dim_products (
    product_id                  VARCHAR(36)     NOT NULL,
    category_name_portuguese    VARCHAR(100)    NULL,
    category_name_english       VARCHAR(100)    NOT NULL DEFAULT 'unclassified',
    product_weight_g            INT             NULL,
    product_length_cm           INT             NULL,
    product_height_cm           INT             NULL,
    product_width_cm            INT             NULL,
    PRIMARY KEY (product_id),
    INDEX idx_prod_cat_eng (category_name_english)
) ENGINE=InnoDB;

-- SELLER / RESTAURANT PARTNERS (Entity Grain: Unique Merchant Partner)
DROP TABLE IF EXISTS dim_sellers;
CREATE TABLE dim_sellers (
    seller_id                   VARCHAR(36)     NOT NULL,
    seller_zip_code_prefix      VARCHAR(10)     NOT NULL,
    seller_city                 VARCHAR(100)    NOT NULL,
    seller_state                VARCHAR(2)      NOT NULL,
    PRIMARY KEY (seller_id),
    INDEX idx_seller_state (seller_state)
) ENGINE=InnoDB;

-- GEOGRAPHY REFERENCE (Entity Grain: Zip Code Prefix)
DROP TABLE IF EXISTS dim_geography;
CREATE TABLE dim_geography (
    zip_code_prefix             VARCHAR(10)     NOT NULL,
    latitude                    DECIMAL(10, 7)  NULL,
    longitude                   DECIMAL(10, 7)  NULL,
    city                        VARCHAR(100)    NOT NULL,
    state                       VARCHAR(2)      NOT NULL,
    PRIMARY KEY (zip_code_prefix, city, state),
    INDEX idx_geo_state (state)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 2. FACT TABLES
-- -----------------------------------------------------------------------------

-- CENTRAL ORDER LIFECYCLE (Entity Grain: One Row per Order)
DROP TABLE IF EXISTS fact_orders;
CREATE TABLE fact_orders (
    order_id                        VARCHAR(36)     NOT NULL,
    customer_id                     VARCHAR(36)     NOT NULL,
    order_status                    VARCHAR(20)     NOT NULL,
    order_purchase_timestamp        DATETIME        NOT NULL,
    order_approved_at               DATETIME        NULL,
    order_delivered_carrier_date    DATETIME        NULL,
    order_delivered_customer_date   DATETIME        NULL,
    order_estimated_delivery_date   DATETIME        NOT NULL,
    is_delivered                    TINYINT(1)      GENERATED ALWAYS AS (CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END) STORED,
    order_year_month                VARCHAR(7)      GENERATED ALWAYS AS (DATE_FORMAT(order_purchase_timestamp, '%Y-%m')) STORED,
    PRIMARY KEY (order_id),
    INDEX idx_order_cust (customer_id),
    INDEX idx_order_status (order_status),
    INDEX idx_order_date (order_purchase_timestamp),
    INDEX idx_order_ym (order_year_month)
) ENGINE=InnoDB;

-- ORDER ITEMS (Entity Grain: One Row per Order Item Line)
DROP TABLE IF EXISTS fact_order_items;
CREATE TABLE fact_order_items (
    order_id                    VARCHAR(36)     NOT NULL,
    order_item_id               INT             NOT NULL,
    product_id                  VARCHAR(36)     NOT NULL,
    seller_id                   VARCHAR(36)     NOT NULL,
    shipping_limit_date         DATETIME        NOT NULL,
    price                       DECIMAL(10, 2)  NOT NULL,
    freight_value               DECIMAL(10, 2)  NOT NULL,
    line_total_gmv              DECIMAL(10, 2)  GENERATED ALWAYS AS (price + freight_value) STORED,
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_item_product (product_id),
    INDEX idx_item_seller (seller_id)
) ENGINE=InnoDB;

-- ORDER PAYMENTS (Entity Grain: One Row per Payment Settlement)
DROP TABLE IF EXISTS fact_order_payments;
CREATE TABLE fact_order_payments (
    order_id                    VARCHAR(36)     NOT NULL,
    payment_sequential          INT             NOT NULL,
    payment_type                VARCHAR(30)     NOT NULL,
    payment_installments        INT             NOT NULL,
    payment_value               DECIMAL(10, 2)  NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    INDEX idx_pay_type (payment_type)
) ENGINE=InnoDB;

-- CUSTOMER REVIEWS (Entity Grain: One Row per Survey Response)
DROP TABLE IF EXISTS fact_order_reviews;
CREATE TABLE fact_order_reviews (
    review_id                   VARCHAR(36)     NOT NULL,
    order_id                    VARCHAR(36)     NOT NULL,
    review_score                TINYINT         NOT NULL,
    review_creation_date        DATETIME        NOT NULL,
    review_answer_timestamp     DATETIME        NOT NULL,
    PRIMARY KEY (review_id, order_id),
    INDEX idx_rev_order (order_id),
    INDEX idx_rev_score (review_score)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 3. ANALYTICAL AGGREGATION VIEW (Order-Level Grain Summary)
-- Prevents Cartesian explosions by pre-aggregating item and payment values
-- -----------------------------------------------------------------------------

DROP VIEW IF EXISTS v_order_summary;
CREATE VIEW v_order_summary AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    o.order_year_month,
    o.is_delivered,
    
    -- Item-level Pre-aggregations
    COALESCE(i.item_count, 0)               AS total_items,
    COALESCE(i.distinct_sellers, 0)        AS distinct_sellers,
    COALESCE(i.goods_subtotal, 0.00)       AS goods_subtotal,
    COALESCE(i.freight_total, 0.00)        AS freight_total,
    COALESCE(i.order_gmv, 0.00)            AS order_gmv,
    
    -- Payment Pre-aggregations
    COALESCE(p.payment_total, 0.00)        AS payment_total,
    COALESCE(p.payment_methods_count, 0)   AS payment_methods_count,
    
    -- Review Score
    r.avg_review_score,
    
    -- Logistics SLA metrics (in fractional days)
    TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_delivered_customer_date) / 24.0 AS actual_delivery_lead_days,
    TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_estimated_delivery_date) / 24.0 AS promised_delivery_lead_days,
    TIMESTAMPDIFF(HOUR, o.order_estimated_delivery_date, o.order_delivered_customer_date) / 24.0 AS sla_delay_days,
    CASE 
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1 
        ELSE 0 
    END AS is_on_time

FROM fact_orders o
JOIN dim_customers c 
    ON o.customer_id = c.customer_id

LEFT JOIN (
    SELECT
        order_id,
        COUNT(*)                        AS item_count,
        COUNT(DISTINCT seller_id)       AS distinct_sellers,
        SUM(price)                      AS goods_subtotal,
        SUM(freight_value)              AS freight_total,
        SUM(price + freight_value)      AS order_gmv
    FROM fact_order_items
    GROUP BY order_id
) i ON o.order_id = i.order_id

LEFT JOIN (
    SELECT
        order_id,
        SUM(payment_value)              AS payment_total,
        COUNT(DISTINCT payment_type)    AS payment_methods_count
    FROM fact_order_payments
    GROUP BY order_id
) p ON o.order_id = p.order_id

LEFT JOIN (
    SELECT
        order_id,
        AVG(review_score)               AS avg_review_score
    FROM fact_order_reviews
    GROUP BY order_id
) r ON o.order_id = r.order_id;
