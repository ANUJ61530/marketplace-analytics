# Data Limitations & Analytical Transparency

## 1. Context & Purpose
This portfolio project is designed to demonstrate the analytical rigor, business intuition, and technical execution expected of a **Product Analyst / Analytics Engineer** in high-velocity marketplace ecosystems (such as Eternal, Zomato, and Blinkit).

To ensure complete ethical integrity and transparency, this document details the source data, domain trade-offs, genuine limitations, and modeling adaptations.

---

## 2. Dataset Foundation & Attribution
The empirical foundation of this project is based on the **Olist Brazilian E-Commerce Public Dataset** (available via Kaggle under the CC BY-NC-SA 4.0 license), spanning approximately **100,000 anonymized orders** between 2016 and 2018.

### Explicit Domain Distinction
- **What this dataset IS**: A multi-seller department store e-commerce marketplace dataset operating across Brazilian states, capturing real commercial logistics, multi-item order carts, split payments, and customer satisfaction reviews.
- **What this dataset IS NOT**: This is **NOT** proprietary data from Zomato, Eternal, Blinkit, Swiggy, Uber Eats, or any on-demand food delivery company.
- **Why this analog works**: The unit economics of a multi-sided marketplace—Active Customers, Frequency, Average Order Value (AOV), Gross Merchandise Value (GMV), seller fulfillment variance, geographic density, and customer cohorts—translate directly to on-demand delivery platforms.

---

## 3. What Exists vs. What Does Not Exist

| Marketplace Dimension | Olist Native Field Availability | Status in this Project | Analytical Handling |
| :--- | :--- | :--- | :--- |
| **Order Timestamps** | `purchase_timestamp`, `approved_at`, `delivered_carrier_date`, `delivered_customer_date`, `estimated_delivery_date` | **Native** | Analyzed as order lead time and delivery promise adherence. |
| **Monetary Values** | `price`, `freight_value`, `payment_value`, `payment_installments` | **Native** | Separated strictly into Item Subtotal, Freight, and Tender Settlement. |
| **Customers & Sellers** | Unique IDs, City, State, Geolocation Zip Prefixes | **Native** | Analyzed for geographic concentration and seller marketplace distribution. |
| **Product Categories** | Portuguese names mapped to English translations | **Native** | Used for category contribution analysis and basket mix. |
| **Customer Reviews** | 1 to 5 star ratings, survey creation and answer timestamps | **Native** | Used as a customer satisfaction (CSAT) proxy. |
| **Restaurant Data** | None (General retail merchants) | **Missing** | Sellers are treated as Merchant Partners; food-specific attributes (cuisine, prep time) are maintained as separate synthetic extensions. |
| **Delivery Partner (Rider) Data** | None (3rd party postal/freight carriers) | **Missing** | Carrier transit time is tracked, but rider fleet telemetry (acceptance rate, batching, GPS traces) is not fabricated. |
| **App Funnel Telemetry** | None (No clickstream / event-level logs) | **Missing** | Described via an analytical funnel framework and synthetic event demonstration schema. |
| **Promised vs Actual Minutes** | Granularity is day/hour, not minute-level SLA | **Missing** | Analyzed at day-level SLA variance; sub-hour delivery promises are framed theoretically. |
| **Cancellation Reasons** | `order_status` ('canceled', 'unavailable') only | **Missing** | Tracked at aggregate status level; root cause taxonomy (merchant rejection vs rider shortage) is flagged as required telemetry. |

---

## 4. Methodological Safeguards Against Common Traps

### A. The "Blind Join" Metric Duplication Trap
- In multi-item orders, joining `orders` directly to `order_items` and `order_payments` produces a Cartesian product if multiple items and split payment tenders exist on the same order.
- **Our Safeguard**: Order-level GMV is aggregated strictly at the `order_items` grain (`SUM(price + freight_value)` grouped by `order_id`) before joining to `orders`. Payment values are validated independently at the `order_payments` grain.

### B. Confusing "Revenue" with GMV
- In a 3P marketplace, GMV (Gross Merchandise Value = item subtotal + delivery fee + taxes) is NOT platform revenue. Platform revenue consists of take-rates (commission %), delivery fee markups, and ad revenues.
- **Our Safeguard**: Metrics are explicitly labeled **GMV**, **Gross Order Value (GOV)**, or **Payment Settlement Value**. If platform revenue is modeled, a clear take-rate parameter (e.g., 18% commission) is documented.

### C. The False Causation Trap in RCA
- A decline in GMV correlated with an increase in average delivery time does not prove delivery delays caused the revenue drop without controlling for geographic supply shocks or rain events.
- **Our Safeguard**: The Root Cause Analysis decomposes revenue mathematically (`GMV = Active Users × Orders/User × AOV`) and separates **mathematical accounting drivers** from **hypothesized operational root causes**.

---

## 5. Synthetic Extensions & Scenario Disclosures
To test interview-critical product analyst skills (e.g., diagnosing a sudden 10% MoM revenue drop or diagnosing a conversion funnel), this repository includes two clearly segregated components:
1. **Historical Baseline**: Computed directly on the clean empirical marketplace data.
2. **Flagship RCA Scenario (Month MoM Drop)**: A simulated recent operating month introducing a realistic 10.4% GMV contraction caused by a dual shock: a drop in new customer acquisition in secondary cities combined with an AOV compression in core categories due to aggressive low-ticket unbundling. All simulated scenarios are marked with `is_synthetic = TRUE` or identified in documentation.
