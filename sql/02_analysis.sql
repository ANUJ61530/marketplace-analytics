-- Business questions on the Olist marketplace data.
-- Each query starts with a "-- name:" line so the notebook can find it.
-- All queries read from order_facts (one row per order) unless noted.

-- name: q1_monthly_trend
-- Q1. How are orders, GMV and basket size trending month by month?
-- GMV = item price + freight. Canceled/unavailable orders are excluded.
-- LAG() looks at the previous month so we can show month-on-month growth.
WITH monthly AS (
    SELECT month,
           COUNT(*)            AS orders,
           ROUND(SUM(gmv), 0)  AS gmv,
           ROUND(AVG(gmv), 2)  AS aov
    FROM order_facts
    WHERE order_status NOT IN ('canceled', 'unavailable')
      AND gmv IS NOT NULL
      AND month BETWEEN '2017-01' AND '2018-08'   -- earlier/later months are nearly empty
    GROUP BY month
)
SELECT month, orders, gmv, aov,
       ROUND(100.0 * (gmv - LAG(gmv) OVER (ORDER BY month))
             / LAG(gmv) OVER (ORDER BY month), 1) AS gmv_mom_pct
FROM monthly
ORDER BY month;

-- name: q2_delivery_by_month
-- Q2. How long does delivery take, and how often do we miss the promised date?
-- Only delivered orders (they have a delivery date).
SELECT month,
       COUNT(*)                        AS delivered_orders,
       ROUND(AVG(delivery_days), 1)    AS avg_delivery_days,
       ROUND(100.0 * AVG(is_late), 1)  AS late_pct
FROM order_facts
WHERE delivery_days IS NOT NULL
  AND month BETWEEN '2017-01' AND '2018-08'
GROUP BY month
ORDER BY month;

-- name: q3_delivery_by_state
-- Q3. Which states have the worst delivery performance?
-- States with fewer than 500 delivered orders are dropped (too noisy).
SELECT state,
       COUNT(*)                        AS delivered_orders,
       ROUND(AVG(delivery_days), 1)    AS avg_delivery_days,
       ROUND(100.0 * AVG(is_late), 1)  AS late_pct,
       ROUND(AVG(review_score), 2)     AS avg_review
FROM order_facts
WHERE delivery_days IS NOT NULL
GROUP BY state
HAVING COUNT(*) >= 500
ORDER BY late_pct DESC;

-- name: q4_late_vs_review
-- Q4. Do late deliveries hurt customer reviews?
-- Orders are grouped by how late they were versus the promised date.
SELECT
    CASE
        WHEN days_vs_promise <= 0 THEN '1. On time or early'
        WHEN days_vs_promise <= 3 THEN '2. 1-3 days late'
        WHEN days_vs_promise <= 7 THEN '3. 4-7 days late'
        ELSE                           '4. 8+ days late'
    END                                                       AS delivery_bucket,
    COUNT(*)                                                  AS orders,
    ROUND(AVG(review_score), 2)                               AS avg_review,
    ROUND(100.0 * AVG(CASE WHEN review_score <= 2 THEN 1.0 ELSE 0 END), 1) AS low_review_pct
FROM order_facts
WHERE days_vs_promise IS NOT NULL AND review_score IS NOT NULL
GROUP BY delivery_bucket
ORDER BY delivery_bucket;

-- name: q5_repeat_customers
-- Q5. How many customers ever come back?
-- customer_unique_id identifies a person (customer_id changes on every order).
WITH per_customer AS (
    SELECT customer_unique_id, COUNT(*) AS orders
    FROM order_facts
    WHERE order_status NOT IN ('canceled', 'unavailable')
    GROUP BY customer_unique_id
)
SELECT COUNT(*)                                             AS customers,
       SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END)        AS repeat_customers,
       ROUND(100.0 * AVG(CASE WHEN orders >= 2 THEN 1.0 ELSE 0 END), 2) AS repeat_pct
FROM per_customer;

-- name: q6_cohort_90d_return
-- Q6. Of customers who first bought in a given month, how many bought again
-- within 90 days? ROW_NUMBER() ranks each customer's orders by time, so
-- rn = 1 is the first order and rn = 2 is the second.
WITH ranked AS (
    SELECT customer_unique_id, purchased_at, month,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                              ORDER BY purchased_at, order_id) AS rn
    FROM order_facts
    WHERE order_status NOT IN ('canceled', 'unavailable')
),
first_order  AS (SELECT * FROM ranked WHERE rn = 1),
second_order AS (SELECT * FROM ranked WHERE rn = 2)
SELECT f.month AS cohort_month,
       COUNT(*) AS new_customers,
       SUM(CASE WHEN s.purchased_at IS NOT NULL
                 AND julianday(s.purchased_at) - julianday(f.purchased_at) <= 90
                THEN 1 ELSE 0 END) AS returned_within_90d,
       ROUND(100.0 * SUM(CASE WHEN s.purchased_at IS NOT NULL
                 AND julianday(s.purchased_at) - julianday(f.purchased_at) <= 90
                THEN 1 ELSE 0 END) / COUNT(*), 2) AS return_pct
FROM first_order f
LEFT JOIN second_order s USING (customer_unique_id)
WHERE f.month BETWEEN '2017-01' AND '2018-05'   -- leaves 90 days of follow-up in the data
GROUP BY f.month
ORDER BY f.month;

-- name: q7_top_categories
-- Q7. Which product categories drive revenue? (item price only, no freight)
-- The running total (SUM() OVER) shows how concentrated revenue is.
WITH cat AS (
    SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
           ROUND(SUM(oi.price), 0) AS revenue,
           COUNT(DISTINCT oi.order_id) AS orders
    FROM order_items oi
    JOIN products p USING (product_id)
    LEFT JOIN category_translation t USING (product_category_name)
    GROUP BY category
)
SELECT category, orders, revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1) AS share_pct,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC)
             / SUM(revenue) OVER (), 1)                  AS cumulative_share_pct
FROM cat
ORDER BY revenue DESC
LIMIT 10;

-- name: q8_seller_concentration
-- Q8. How concentrated is revenue among sellers?
-- NTILE(10) splits sellers into 10 equal groups by revenue (1 = biggest).
WITH seller_rev AS (
    SELECT seller_id, SUM(price) AS revenue
    FROM order_items
    GROUP BY seller_id
),
deciles AS (
    SELECT seller_id, revenue,
           NTILE(10) OVER (ORDER BY revenue DESC) AS decile
    FROM seller_rev
)
SELECT decile,
       COUNT(*)                                              AS sellers,
       ROUND(SUM(revenue), 0)                                AS revenue,
       ROUND(100.0 * SUM(revenue) / (SELECT SUM(revenue) FROM seller_rev), 1) AS share_pct
FROM deciles
GROUP BY decile
ORDER BY decile;

-- name: q9_first_order_experience
-- Q9. Do customers whose FIRST order arrived late come back less often?
-- Same ranking idea as Q6. Only delivered first orders from cohorts that have
-- at least 90 days of follow-up are used.
WITH ranked AS (
    SELECT customer_unique_id, purchased_at, month, is_late, review_score,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                              ORDER BY purchased_at, order_id) AS rn
    FROM order_facts
    WHERE order_status NOT IN ('canceled', 'unavailable')
),
first_order  AS (SELECT * FROM ranked WHERE rn = 1),
second_order AS (SELECT * FROM ranked WHERE rn = 2)
SELECT CASE WHEN f.is_late = 1 THEN 'First order late' ELSE 'First order on time' END AS first_order,
       COUNT(*) AS customers,
       ROUND(100.0 * SUM(CASE WHEN s.purchased_at IS NOT NULL
                 AND julianday(s.purchased_at) - julianday(f.purchased_at) <= 90
                THEN 1 ELSE 0 END) / COUNT(*), 2) AS return_within_90d_pct
FROM first_order f
LEFT JOIN second_order s USING (customer_unique_id)
WHERE f.is_late IS NOT NULL
  AND f.month BETWEEN '2017-01' AND '2018-05'
GROUP BY first_order
ORDER BY first_order DESC;
