# Data Dictionary & Schema Documentation

## 1. Relational Architecture & Star Schema Design

This analytical warehouse is designed around a Kimball-style Dimensional Model optimized for marketplace intelligence. Raw source tables are transformed into clean dimension and fact tables, strictly preventing metric inflation through grain-isolated aggregations.

```
                    +-------------------+
                    |   dim_customers   |
                    +-------------------+
                              | 1
                              |
                              | N
+------------------+ 1      N +-------------------+ N      1 +--------------------+
|  dim_geography   |----------|    fact_orders    |----------| fact_order_reviews |
+------------------+          +-------------------+          +--------------------+
                                | 1             | 1
                                |               |
                                | N             | N
                      +------------------+     +---------------------+
                      | fact_order_items |     | fact_order_payments |
                      +------------------+     +---------------------+
                        | N          | N
                        |            |
                        | 1          | 1
               +--------------+   +-------------+
               | dim_products |   | dim_sellers |
               +--------------+   +-------------+
```

---

## 2. Table Specifications & Grain Validation

### Table: `fact_orders`
- **Description**: Central order fulfillment fact table.
- **Grain**: Exactly **One row per unique order (`order_id`)**.
- **Business Rule**: Uncompleted or canceled orders are retained for operational funnel analysis, but filtered out for net GMV reporting (`order_status = 'delivered'`).

| Column Name | Data Type | Nullable | Primary / Foreign Key | Description | Example / Allowed Values |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `order_id` | VARCHAR(36) | NO | PK | Unique identifier of the transaction order | `e481f51cbdc54678b7cc49136f2d6af7` |
| `customer_id` | VARCHAR(36) | NO | FK -> `dim_customers` | Order-scoped customer token linking to buyer identity | `9ef432eb6251297304e76186b10a928d` |
| `order_status` | VARCHAR(20) | NO | - | Lifecycle status of the order | `delivered`, `shipped`, `canceled`, `invoiced` |
| `order_purchase_timestamp` | DATETIME | NO | - | Timestamp when buyer placed the order | `2018-05-16 19:03:39` |
| `order_approved_at` | DATETIME | YES | - | Payment gateway settlement approval timestamp | `2018-05-16 19:17:45` |
| `order_delivered_carrier_date`| DATETIME | YES | - | Timestamp package handed off to logistics partner | `2018-05-17 12:24:00` |
| `order_delivered_customer_date`| DATETIME | YES | - | Actual delivery timestamp at customer doorstep | `2018-05-21 14:11:00` |
| `order_estimated_delivery_date`| DATETIME | NO | - | Promised SLA delivery date shown to customer | `2018-06-05 00:00:00` |
| `order_item_count` | INT | NO | Derived | Total count of items bundled in this order | `1`, `2`, `5` |
| `order_subtotal` | DECIMAL(10,2)| NO | Derived | Sum of item item prices (`SUM(price)`) | `129.90` |
| `order_freight` | DECIMAL(10,2)| NO | Derived | Sum of freight shipping fees (`SUM(freight_value)`) | `18.23` |
| `order_gmv` | DECIMAL(10,2)| NO | Derived | Total Gross Merchandise Value (`subtotal + freight`) | `148.13` |

---

### Table: `fact_order_items`
- **Description**: Line-item details representing individual goods purchased within an order.
- **Grain**: Exactly **One row per `(order_id, order_item_id)`**.
- **Crucial Note**: Do NOT calculate order GMV by summing this table without grouping by `order_id` first.

| Column Name | Data Type | Nullable | Primary / Foreign Key | Description | Example / Range |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `order_id` | VARCHAR(36) | NO | PK, FK -> `fact_orders` | Order identifier | `e481f51cbdc54678...` |
| `order_item_id` | INT | NO | PK | Sequential sequence item number in order (1, 2, 3...) | `1` |
| `product_id` | VARCHAR(36) | NO | FK -> `dim_products` | Product catalog identifier | `87285b34884572bc...` |
| `seller_id` | VARCHAR(36) | NO | FK -> `dim_sellers` | Merchant / store partner fulfilling the item | `3504c0c971292227...` |
| `shipping_limit_date` | DATETIME | NO | - | Merchant dispatch cutoff deadline | `2018-05-22 19:07:35` |
| `price` | DECIMAL(10,2)| NO | - | Item list price (local currency BRL) | `29.99` |
| `freight_value` | DECIMAL(10,2)| NO | - | Shipping/handling fee allocated to item | `8.72` |

---

### Table: `fact_order_payments`
- **Description**: Payment authorization records per transaction.
- **Grain**: Exactly **One row per `(order_id, payment_sequential)`**.
- **Important**: An order can be split across vouchers and credit cards.

| Column Name | Data Type | Nullable | Primary / Foreign Key | Description | Allowed Values |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `order_id` | VARCHAR(36) | NO | PK, FK -> `fact_orders` | Order identifier | `e481f51cbdc54678...` |
| `payment_sequential` | INT | NO | PK | Sequential payment attempt index (1, 2...) | `1` |
| `payment_type` | VARCHAR(20) | NO | - | Tender instrument | `credit_card`, `boleto`, `voucher`, `debit_card` |
| `payment_installments` | INT | NO | - | Number of financing installment months | `1` (full) to `24` |
| `payment_value` | DECIMAL(10,2)| NO | - | Monetary amount settled via this tender | `55.00` |

---

### Table: `dim_customers`
- **Description**: Master customer directory tracking both transaction tokens and unique consumer entities.
- **Grain**: Exactly **One row per unique consumer (`customer_unique_id`)**.
- **Important Architecture**: Olist assigns a fresh `customer_id` for every order, while `customer_unique_id` identifies the recurring real-world person.

| Column Name | Data Type | Nullable | Primary / Foreign Key | Description | Example |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `customer_unique_id` | VARCHAR(36) | NO | PK | Permanent customer identity across repeat visits | `871766c5855e863...` |
| `first_order_date` | DATE | NO | Derived | Customer cohort birth date (earliest order date) | `2017-02-14` |
| `customer_zip_code_prefix` | VARCHAR(10) | NO | FK -> `dim_geography` | Postal code prefix | `01452` |
| `customer_city` | VARCHAR(100) | NO | - | Customer resident city | `sao paulo` |
| `customer_state` | VARCHAR(2) | NO | - | Brazilian state 2-letter abbreviation | `SP`, `RJ`, `MG` |

---

### Table: `dim_products`
- **Description**: Product catalog dimension enriched with standardized English category taxonomies.
- **Grain**: Exactly **One row per `product_id`**.

| Column Name | Data Type | Nullable | Primary / Foreign Key | Description | Example |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `product_id` | VARCHAR(36) | NO | PK | Unique product SKU identifier | `1e9e8ef04dbcff45...` |
| `category_name_english` | VARCHAR(100) | NO | - | Standardized English taxonomy | `health_beauty`, `bed_bath_table` |
| `category_name_portuguese` | VARCHAR(100) | YES | - | Raw catalog taxonomy | `beleza_saude` |
| `product_weight_g` | INT | YES | - | Physical weight in grams | `700` |
| `product_length_cm` | INT | YES | - | Physical length dimension | `30` |
| `product_height_cm` | INT | YES | - | Physical height dimension | `25` |
| `product_width_cm` | INT | YES | - | Physical width dimension | `20` |

---

### Table: `dim_sellers`
- **Description**: Merchant partner directory.
- **Grain**: Exactly **One row per `seller_id`**.

| Column Name | Data Type | Nullable | Primary / Foreign Key | Description | Example |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `seller_id` | VARCHAR(36) | NO | PK | Merchant identifier | `3442f8959a84dea...` |
| `seller_zip_code_prefix` | VARCHAR(10) | NO | FK -> `dim_geography` | Merchant postal code | `13080` |
| `seller_city` | VARCHAR(100) | NO | - | Merchant hub city | `campinas` |
| `seller_state` | VARCHAR(2) | NO | - | Merchant home state | `SP` |

---

### Table: `fact_order_reviews`
- **Description**: Post-fulfillment customer satisfaction feedback.
- **Grain**: Exactly **One row per `review_id`**.

| Column Name | Data Type | Nullable | Primary / Foreign Key | Description | Allowed Values |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `review_id` | VARCHAR(36) | NO | PK | Survey response ID | `7bc24e225da...` |
| `order_id` | VARCHAR(36) | NO | FK -> `fact_orders` | Target order reviewed | `b1874f64d08...` |
| `review_score` | TINYINT | NO | - | CSAT Rating (1=Terrible, 5=Excellent) | `1`, `2`, `3`, `4`, `5` |
| `review_creation_date` | DATETIME | NO | - | Date survey dispatched | `2018-05-22 00:00:00` |
| `review_answer_timestamp` | DATETIME | NO | - | Date survey completed by customer | `2018-05-23 12:05:14` |

---

### Demonstration Table: `synthetic_funnel_events`
- **Description**: Explicitly labeled synthetic clickstream schema demonstrating app conversion tracking.
- **Grain**: Exactly **One row per `(session_id, event_id)`**.

| Column Name | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `event_id` | VARCHAR(36) | NO | Unique event log identifier |
| `session_id` | VARCHAR(36) | NO | Browser / App session token |
| `user_unique_id` | VARCHAR(36) | YES | Logged-in user identifier (null for guest visitors) |
| `event_name` | VARCHAR(50) | NO | `app_open`, `restaurant_view`, `item_view`, `add_to_cart`, `checkout_start`, `order_placed` |
| `event_timestamp` | DATETIME | NO | Precise microsecond timestamp of user action |
| `platform` | VARCHAR(20) | NO | `iOS`, `Android`, `Web` |
