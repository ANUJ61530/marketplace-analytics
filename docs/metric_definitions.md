# Metric Definitions & Analytical Taxonomies

Every metric reported in this project adheres to strict analytical standards. Ambiguous terminology (such as calling Gross Merchandise Value "revenue") is eliminated.

---

## 1. Executive Summary of Key Formulas

| Metric Name | Mathematical Formula | Base Grain | Operational Filter |
| :--- | :--- | :--- | :--- |
| **Gross Merchandise Value (GMV)** | $\sum (\text{Price} + \text{Freight})$ | Order Line Items | `order_status = 'delivered'` |
| **Gross Order Value (GOV / Basket)**| $\sum (\text{Price})$ | Order Line Items | `order_status = 'delivered'` |
| **Net Payment Value** | $\sum (\text{Payment Value})$ | Order Payments | `order_status = 'delivered'` |
| **Platform Take-Rate Revenue (Modeled)** | $\text{GMV} \times \text{TakeRate\%} + \text{DeliveryMargin}$ | Orders | `order_status = 'delivered'` |
| **Average Order Value (AOV)** | $\frac{\text{Delivered GMV}}{\text{Delivered Order Count}}$ | Aggregated Order | Completed orders only |
| **Monthly Active Buyers (MAB)** | $\text{COUNT(DISTINCT } customer\_unique\_id)$ | Monthly Period | Placed $\ge 1$ delivered order |
| **Repeat Buyer Rate** | $\frac{\text{Buyers with } \ge 2 \text{ Lifetime Orders}}{\text{Total Unique Buyers}}$ | Customer Lifetime | Excludes current month new signups |
| **Fulfillment SLA Adherence Rate** | $\frac{\text{Orders with Delivery Date} \le \text{Estimated Date}}{\text{Total Delivered Orders}}$ | Orders | Excludes canceled orders |
| **On-Time In-Full (OTIF) Rate** | $\frac{\text{On-Time Delivered Orders with Review Score} \ge 4}{\text{Total Delivered Orders}}$ | Orders | Requires review record |

---

## 2. In-Depth Metric Specifications

### 2.1 Gross Merchandise Value (GMV) vs Platform Net Revenue
* **Definition**: Total dollar volume of merchandise transactions and delivery freight transacted through the marketplace platform before merchant payouts, refunds, and promo discounts.
* **Why it matters**: Demonstrates platform liquidity and commercial throughput. It is NOT platform accounting revenue.
* **SQL Implementation**:
  ```sql
  -- Computed from item-level grain to prevent payment split distortion
  SELECT
      DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
      SUM(oi.price + oi.freight_value) AS total_gmv,
      SUM(oi.price) AS total_goods_value,
      SUM(oi.freight_value) AS total_freight_value
  FROM fact_orders o
  JOIN fact_order_items oi ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY 1;
  ```
* **Inclusions**: Completed (`delivered`) orders including product list price and consumer freight charges.
* **Exclusions**: Canceled, unavailable, and returned orders; credit card interest surcharges added by payment acquirers.

---

### 2.2 Average Order Value (AOV)
* **Definition**: Average gross transactional spend per fulfilled order.
* **Why it matters**: A fundamental driver of marketplace unit economics. An AOV contraction can compress delivery profitability even when order volume is growing.
* **Formula**:
  $$\text{AOV} = \frac{\text{Total GMV}}{\text{Total Delivered Orders}} = \text{Average Basket Price} \times \text{Items Per Order} + \text{Average Freight}$$
* **Decomposition**:
  Can be split into:
  1. Average Item Price ($\frac{\text{Subtotal}}{\text{Total Items}}$)
  2. Basket Size / Items per Order ($\frac{\text{Total Items}}{\text{Total Orders}}$)
  3. Freight per Order ($\frac{\text{Total Freight}}{\text{Total Orders}}$)

---

### 2.3 Monthly Active Customers (MAC) & Frequency
* **Definition**: Unique buyers who executed at least one successfully delivered purchase in the calendar month.
* **Grain**: Count of distinct `customer_unique_id` (not `customer_id` which changes per order).
* **Formula**:
  $$\text{Order Frequency} = \frac{\text{Total Delivered Orders in Month}}{\text{Unique Active Customers in Month}}$$

---

### 2.4 New vs. Repeat Customer Mix
* **Definition**:
  - **New Customer**: A customer placing their very first lifetime order on the platform within the observation period.
  - **Repeat Customer**: A customer who has placed at least one prior order in any previous period.
* **SQL Logic**:
  ```sql
  WITH customer_cohorts AS (
      SELECT
          customer_unique_id,
          MIN(order_purchase_timestamp) AS first_order_date
      FROM fact_orders o
      JOIN dim_customers c ON o.customer_id = c.customer_id
      WHERE o.order_status = 'delivered'
      GROUP BY customer_unique_id
  )
  SELECT
      DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
      COUNT(DISTINCT CASE
          WHEN DATE_TRUNC('month', o.order_purchase_timestamp) = DATE_TRUNC('month', cc.first_order_date)
          THEN c.customer_unique_id END) AS new_customers,
      COUNT(DISTINCT CASE
          WHEN DATE_TRUNC('month', o.order_purchase_timestamp) > DATE_TRUNC('month', cc.first_order_date)
          THEN c.customer_unique_id END) AS repeat_customers
  FROM fact_orders o
  JOIN dim_customers c ON o.customer_id = c.customer_id
  JOIN customer_cohorts cc ON c.customer_unique_id = cc.customer_unique_id
  WHERE o.order_status = 'delivered'
  GROUP BY 1;
  ```

---

### 2.5 Revenue Root Cause Decomposition Framework
Any change in total GMV ($\Delta \text{GMV}$) between Period 0 and Period 1 decomposes into mathematically mutually exclusive and collectively exhaustive (MECE) drivers:

$$\text{GMV} = \text{Active Customers} \times \text{Order Frequency} \times \text{AOV}$$

Taking logarithmic differentiation or finite step decomposition:
1. **Customer Volume Effect**:
   $$\Delta \text{GMV}_{\text{Volume}} = (\text{Customers}_1 - \text{Customers}_0) \times \text{Frequency}_0 \times \text{AOV}_0$$
2. **Frequency Effect**:
   $$\Delta \text{GMV}_{\text{Frequency}} = \text{Customers}_1 \times (\text{Frequency}_1 - \text{Frequency}_0) \times \text{AOV}_0$$
3. **Basket / AOV Effect**:
   $$\Delta \text{GMV}_{\text{AOV}} = \text{Customers}_1 \times \text{Frequency}_1 \times (\text{AOV}_1 - \text{AOV}_0)$$

Sum of these three effects equals $\text{GMV}_1 - \text{GMV}_0$ exactly.

---

### 2.6 Delivery SLA & Quality Metrics
* **Lead Time**: Days/hours between `order_purchase_timestamp` and `order_delivered_customer_date`.
* **Estimated Lead Time**: Promised days between `order_purchase_timestamp` and `order_estimated_delivery_date`.
* **SLA Variance (Days Late)**:
  $$\text{Delay Days} = \text{Actual Delivery Date} - \text{Estimated Delivery Date}$$
  - $\le 0$: On-time or early delivery.
  - $> 0$: Breach of SLA promise.
