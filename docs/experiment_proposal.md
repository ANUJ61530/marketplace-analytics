# Product Experimentation Proposal: High-Value At-Risk Reactivation

## Executive Summary
Based on our RFM customer segmentation and cohort retention findings, **Month-1 cohort drop-off exceeds 96%** and **"At-Risk High-Value" customers** account for over 18% of historical GMV but have not transacted in the last 60–120 days. 

This document details an institutional A/B testing design to test whether targeted, dynamic free-delivery vouchers can reactivate dormant high-value customers profitably without triggering incentive cannibalization.

---

## 1. Problem Statement & Opportunity
- **Observation**: Once a high-spending customer exceeds 60 days of inactivity, their organic return probability drops below 4.2%.
- **Business Cost**: Acquiring a replacement customer via paid performance marketing costs ~$24 CAC, whereas activating an existing dormant buyer costs significantly less if margin leakage is controlled.
- **Hypothesis**: Offering a time-decaying "Free Delivery on Next Order above $75" voucher to *At-Risk High-Value* customers will increase 30-day reactivation rates by at least **2.5 percentage points** (from 4.0% to 6.5%) with a positive net incremental margin.

---

## 2. Experiment Design & Architecture

```
                   Target Population: RFM Segment "At-Risk High-Value"
                    (Recency 60-120 days, Historical Orders >= 2, GMV > P75)
                                          |
                                          | Stratified Randomization (by City & Hist Spend)
                        +-----------------+-----------------+
                        | 50%                               | 50%
                        v                                   v
             [ Control Group (A) ]               [ Treatment Group (B) ]
             Standard Lifecycle Comms            Targeted Free-Delivery Push + In-App Banner
             (No monetary incentive)             (Free Freight voucher on orders > $75, valid 14 days)
```

### 2.1 Target Population Definition
- **Inclusion Criteria**:
  1. `customer_unique_id` classified into the `At-Risk` or `Hibernating` segment.
  2. Days since last order: $60 \le \text{Recency} \le 120$ days.
  3. Historical lifetime GMV $\ge$ 75th percentile ($> \$180$).
  4. At least 1 delivered order with review score $\ge 3$ (filters out users churning due to catastrophic service failure).
- **Exclusion Criteria**:
  - Customers with unresolved open customer support tickets.
  - Fraud / multi-account flagged devices.

### 2.2 Randomization Strategy & Unit
- **Randomization Unit**: `customer_unique_id` (hashed via salted MD5/MurmurHash modulo 100).
- **Stratification Dimensions**:
  1. Geographic tier (Tier-1 Metro: SP, RJ vs. Tier-2/3 States).
  2. Historical AOV bracket ($<\$100, \$100-\$250, >\$250$).
- **Why Customer-level (and not Order-level)**: Order-level randomization would allow the same buyer to see vouchers on some visits and not others, contaminating intent and causing user frustration.

---

## 3. Metrics Hierarchy & Decision Framework

### Primary Success Metric
* **30-Day Reactivation Rate**:
  $$\text{Reactivation Rate} = \frac{\text{Unique Customers placing } \ge 1 \text{ delivered order within 30 days of campaign dispatch}}{\text{Total Customers assigned to cohort}}$$
  * *Minimum Detectable Effect (MDE)*: +2.0 percentage points relative lift.

### Secondary Product Metrics
1. **Gross Incremental Orders**: Total orders generated per 1,000 users assigned.
2. **Net Incremental Margin (NIM)**:
   $$\text{NIM} = \sum (\text{Take-Rate Revenue} - \text{Voucher Subsidy Cost} - \text{Delivery Cost Share})$$
3. **Repeat Order Rate in Window (Orders > 1 post-reactivation)**: Evaluates if reactivation creates durable habits or single-transaction coupon burn.

### Guardrail Metrics (Stop Conditions)
* **AOV Dilution**: If treatment AOV drops by $> 15\%$ compared to control, halt treatment (indicates users splitting purchases to exploit coupons).
* **Delivery Partner Surcharge / Freight Burn**: If subsidy spend exceeds $4.20 per active customer.
* **Unsubscribe / Push Notification Opt-Out Rate**: Must not exceed control by $> 0.3$ pp.

---

## 4. Statistical Power & Sample Size Sizing

Using standard statistical power conventions ($\alpha = 0.05$ two-tailed, power $1 - \beta = 0.80$):
- **Baseline Conversion ($p_0$)**: 4.0%
- **Expected Treatment Conversion ($p_1$)**: 6.0% (MDE = 2.0% absolute, 50% relative lift)
- **Required Sample Size**:
  $$n = \frac{(Z_{\alpha/2}\sqrt{2\bar{p}(1-\bar{p})} + Z_{\beta}\sqrt{p_0(1-p_0) + p_1(1-p_1)})^2}{(p_1 - p_0)^2}$$
  - $n \approx 3,420$ users per variant $\implies$ **Total required sample: 6,840 customers**.
- **Duration**: Given an available at-risk high-value pool of ~14,000 customers, running across 50% allocation reaches full statistical power in **14 days**, tracked for 30 days post-dispatch.

---

## 5. Experiment Risks, Biases & Mitigation

| Threat to Validity | Operational Manifestation | Engineering / Analytical Safeguard |
| :--- | :--- | :--- |
| **Cannibalization** | Users who were going to order anyway use the coupon, leaking margin. | Control group A establishes the exact counterfactual organic conversion rate. NIM metric explicitly deducts voucher cost. |
| **Selection Bias** | Heavily engaged app openers receiving pushes faster than dormant email readers. | Intention-To-Treat (ITT) analysis: evaluate all assigned users regardless of whether they opened the push notification. |
| **Novelty Effect** | Short-term surge in week 1 that evaporates in week 3. | 30-day post-window tracking; evaluate repeat purchase velocity (order 2 post-reactivation). |
| **Network Interference / SUTVA** | Delivery riders being saturated in treatment zones, causing delayed fulfillment for control users. | Stratify assignments geographically; monitor carrier dispatch lead time differences between groups. |
| **Seasonality / Payday Shocks** | Orders spiking during national salary week (first 5 days of month). | Launch date scheduled to encompass a full 14-day cycle across both mid-month and month-end salary periods. |

---

## 6. Post-Experiment Decision Matrix

```
                                  Primary Metric (Reactivation Rate)
                                        Lift Statistically Significant?
                                            /                  \
                                          YES                   NO
                                         /                        \
                  Net Incremental Margin > 0?               Roll back intervention.
                    /                     \                 Analyze friction points:
                  YES                      NO               Was discount too small?
                 /                           \              Did customers churn due to
   [ SHIP TO PRODUCTION ]             [ REFINE THRESHOLD ]   prior bad delivery experience?
   Scale voucher workflow to          Increase minimum spend
   automated CRM lifecycle trigger.   basket from $75 to $95.
```
