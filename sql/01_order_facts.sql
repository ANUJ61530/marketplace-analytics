-- One row per order, with everything we need for analysis.
--
-- Why build this first? An order can have several items and (rarely) several
-- reviews. If we join orders to items and reviews directly, rows multiply and
-- sums get inflated. So items and reviews are collapsed to ONE row per order
-- before they are joined.

DROP TABLE IF EXISTS order_facts;

CREATE TABLE order_facts AS
WITH items AS (
    SELECT order_id,
           SUM(price)         AS item_value,
           SUM(freight_value) AS freight,
           COUNT(*)           AS n_items
    FROM order_items
    GROUP BY order_id
),
reviews AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state                                   AS state,
    o.order_status,
    o.order_purchase_timestamp                         AS purchased_at,
    strftime('%Y-%m', o.order_purchase_timestamp)      AS month,
    i.item_value,
    i.freight,
    i.item_value + i.freight                           AS gmv,
    i.n_items,
    -- days from purchase to delivery (NULL if never delivered)
    ROUND(julianday(o.order_delivered_customer_date)
        - julianday(o.order_purchase_timestamp), 1)    AS delivery_days,
    -- positive = later than the date promised at checkout
    julianday(o.order_delivered_customer_date)
        - julianday(o.order_estimated_delivery_date)   AS days_vs_promise,
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
        ELSE 0
    END                                                AS is_late,
    r.review_score
FROM orders o
JOIN customers c USING (customer_id)
LEFT JOIN items   i USING (order_id)
LEFT JOIN reviews r USING (order_id);
