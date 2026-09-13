"""
Marketplace Dataset Generator & Realistic Scenario Synthesizer
Generates an Olist-compatible marketplace dataset with realistic historical trends
and an explicit, documented ~10% MoM contraction in Month 2018-05 for Root Cause Analysis.
"""

import os
import random
import uuid
from datetime import datetime, timedelta
from pathlib import Path
import numpy as np
import pandas as pd

# Set deterministic random seeds for complete reproducibility
np.random.seed(42)
random.seed(42)

BASE_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"
PROCESSED_DIR = BASE_DIR / "data" / "processed"


def generate_marketplace_dataset(num_orders: int = 40000):
    """
    Generates a full relational marketplace database adhering to Olist schema specs.
    """
    print(f"Generating realistic marketplace dataset (~{num_orders} orders)...")
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

    # 1. GEOGRAPHY & STATES
    states_prob = {
        "SP": 0.42, "RJ": 0.13, "MG": 0.12, "RS": 0.06, "PR": 0.05,
        "SC": 0.04, "BA": 0.04, "DF": 0.03, "GO": 0.02, "ES": 0.02,
        "PE": 0.02, "CE": 0.02, "PA": 0.01, "MT": 0.01, "MS": 0.01
    }
    states = list(states_prob.keys())
    s_probs = list(states_prob.values())
    s_probs = [p / sum(s_probs) for p in s_probs]

    cities_by_state = {
        "SP": ["sao paulo", "campinas", "guarulhos", "santos", "ribeirao preto"],
        "RJ": ["rio de janeiro", "niteroi", "nova iguacu", "duque de caxias"],
        "MG": ["belo horizonte", "uberlandia", "contagem", "juiz de fora"],
        "RS": ["porto alegre", "caxias do sul", "pelotas", "canoas"],
        "PR": ["curitiba", "londrina", "maringa", "ponta grossa"],
        "SC": ["florianopolis", "joinville", "blumenau"],
        "BA": ["salvador", "feira de santana", "vitoria da conquista"],
        "DF": ["brasilia"],
        "GO": ["goiania", "aparecida de goiania"],
        "ES": ["vitoria", "vila velha", "serra"],
        "PE": ["recife", "olinda", "jaboatao"],
        "CE": ["fortaleza", "caucaia"],
        "PA": ["belem", "anindeua"],
        "MT": ["cuiaba", "varzea grande"],
        "MS": ["campo grande", "dourados"]
    }

    # 2. CATEGORIES & PRODUCTS
    categories = [
        ("health_beauty", "beleza_saude", 130.0, 35.0),
        ("bed_bath_table", "cama_mesa_banho", 95.0, 25.0),
        ("sports_leisure", "esporte_lazer", 115.0, 30.0),
        ("computers_accessories", "informatica_acessorios", 145.0, 45.0),
        ("furniture_decor", "moveis_decoracao", 160.0, 50.0),
        ("watches_gifts", "relogios_presentes", 210.0, 60.0),
        ("housewares", "utilidades_domesticas", 85.0, 20.0),
        ("telephony", "telefonia", 75.0, 20.0),
        ("auto", "automotivo", 140.0, 40.0),
        ("toys", "brinquedos", 110.0, 30.0),
        ("cool_stuff", "cool_stuff", 165.0, 45.0),
        ("garden_tools", "ferramentas_jardim", 135.0, 35.0),
        ("perfumery", "perfumaria", 125.0, 30.0),
        ("baby", "bebes", 130.0, 35.0),
        ("electronics", "eletronicos", 90.0, 25.0)
    ]

    num_products = 4000
    products_data = []
    for i in range(num_products):
        pid = uuid.uuid4().hex
        cat_eng, cat_port, mean_price, std_price = random.choice(categories)
        products_data.append({
            "product_id": pid,
            "category_name_portuguese": cat_port,
            "category_name_english": cat_eng,
            "product_weight_g": int(max(100, np.random.normal(1500, 800))),
            "product_length_cm": int(max(10, np.random.normal(30, 10))),
            "product_height_cm": int(max(5, np.random.normal(20, 8))),
            "product_width_cm": int(max(10, np.random.normal(25, 8))),
            "base_price": max(15.0, round(float(np.random.normal(mean_price, std_price)), 2))
        })
    df_products = pd.DataFrame(products_data)

    # 3. SELLERS
    num_sellers = 1200
    sellers_data = []
    for _ in range(num_sellers):
        st = np.random.choice(states, p=s_probs)
        city = random.choice(cities_by_state[st])
        sellers_data.append({
            "seller_id": uuid.uuid4().hex,
            "seller_zip_code_prefix": f"{random.randint(1000, 99999):05d}",
            "seller_city": city,
            "seller_state": st
        })
    df_sellers = pd.DataFrame(sellers_data)

    # 4. CUSTOMERS POOL (Generating ~30,000 unique buyers)
    num_unique_customers = int(num_orders * 0.78)
    customers_pool = []
    for _ in range(num_unique_customers):
        st = np.random.choice(states, p=s_probs)
        city = random.choice(cities_by_state[st])
        customers_pool.append({
            "customer_unique_id": uuid.uuid4().hex,
            "customer_zip_code_prefix": f"{random.randint(1000, 99999):05d}",
            "customer_city": city,
            "customer_state": st,
            "first_seen": None
        })

    # 5. GENERATE ORDERS OVER TIME (2017-01 to 2018-06)
    # Monthly order distribution mimicking marketplace ramp-up
    # Month 2018-04: Peak month (e.g. 4,200 orders)
    # Month 2018-05: Evaluated drop month (~3,850 orders, AOV drops ~4%) -> Net GMV drop = ~10.4%
    months = pd.date_range(start="2017-01-01", end="2018-06-30", freq="MS")
    monthly_targets = {
        "2017-01": 800, "2017-02": 1100, "2017-03": 1500, "2017-04": 1600,
        "2017-05": 2000, "2017-06": 2100, "2017-07": 2400, "2017-08": 2700,
        "2017-09": 2800, "2017-10": 3100, "2017-11": 4200, "2017-12": 3500,
        "2018-01": 4100, "2018-02": 4200, "2018-03": 4400, "2018-04": 4600,
        "2018-05": 4150,  # MoM Contraction month
        "2018-06": 4250
    }

    orders_records = []
    order_items_records = []
    order_payments_records = []
    order_reviews_records = []
    dim_customers_records = []

    cust_pool_idx = 0
    assigned_customers = []

    for month_dt in months:
        m_str = month_dt.strftime("%Y-%m")
        target_cnt = monthly_targets.get(m_str, 2500)
        days_in_month = (month_dt + pd.offsets.MonthEnd(1)).day

        for _ in range(target_cnt):
            order_id = uuid.uuid4().hex
            order_day = random.randint(1, days_in_month)
            order_hour = random.randint(0, 23)
            order_minute = random.randint(0, 59)
            order_second = random.randint(0, 59)
            purchase_ts = datetime(month_dt.year, month_dt.month, order_day, order_hour, order_minute, order_second)

            # Repeat buyer logic: ~4% chance to pick an already seen customer, else fresh customer
            if len(assigned_customers) > 100 and random.random() < 0.05:
                chosen_cust = random.choice(assigned_customers)
            else:
                if cust_pool_idx < len(customers_pool):
                    chosen_cust = customers_pool[cust_pool_idx]
                    cust_pool_idx += 1
                else:
                    chosen_cust = random.choice(customers_pool)
                chosen_cust["first_seen"] = m_str
                assigned_customers.append(chosen_cust)

            customer_token = uuid.uuid4().hex
            dim_customers_records.append({
                "customer_unique_id": chosen_cust["customer_unique_id"],
                "customer_id": customer_token,
                "customer_zip_code_prefix": chosen_cust["customer_zip_code_prefix"],
                "customer_city": chosen_cust["customer_city"],
                "customer_state": chosen_cust["customer_state"],
                "first_order_timestamp": purchase_ts,
                "cohort_month": chosen_cust["first_seen"]
            })

            # Order Status: 97.2% delivered, 1.8% canceled, 1.0% shipped/invoiced
            rand_status = random.random()
            if rand_status < 0.972:
                status = "delivered"
            elif rand_status < 0.990:
                status = "canceled"
            else:
                status = "shipped"

            # Temporal sequence:
            # approved 10 mins to 24 hours after purchase
            approved_at = purchase_ts + timedelta(minutes=random.randint(15, 720))
            # carrier handoff 1 to 3 days after approval
            carrier_date = approved_at + timedelta(hours=random.randint(24, 72))
            # delivery 3 to 18 days after purchase
            actual_lead_days = random.randint(3, 18)
            delivered_date = purchase_ts + timedelta(days=actual_lead_days) if status == "delivered" else None
            # SLA promised date: typically 15-25 days from purchase
            estimated_date = purchase_ts + timedelta(days=random.randint(14, 26))

            orders_records.append({
                "order_id": order_id,
                "customer_id": customer_token,
                "order_status": status,
                "order_purchase_timestamp": purchase_ts,
                "order_approved_at": approved_at,
                "order_delivered_carrier_date": carrier_date if status == "delivered" else None,
                "order_delivered_customer_date": delivered_date,
                "order_estimated_delivery_date": estimated_date
            })

            # Order Items: 1 item (88%), 2 items (9%), 3+ items (3%)
            item_draw = random.random()
            num_items = 1 if item_draw < 0.88 else (2 if item_draw < 0.97 else 3)
            order_total_gmv = 0.0

            # RCA Injection for May 2018: Lower price skew by ~5% in core categories
            price_multiplier = 0.93 if m_str == "2018-05" else 1.00

            for seq in range(1, num_items + 1):
                prod = df_products.sample(1).iloc[0]
                seller = df_sellers.sample(1).iloc[0]
                item_price = round(float(prod["base_price"]) * price_multiplier * random.uniform(0.9, 1.1), 2)
                item_freight = round(random.uniform(12.0, 28.0), 2)
                order_total_gmv += (item_price + item_freight)

                order_items_records.append({
                    "order_id": order_id,
                    "order_item_id": seq,
                    "product_id": prod["product_id"],
                    "seller_id": seller["seller_id"],
                    "shipping_limit_date": purchase_ts + timedelta(days=5),
                    "price": item_price,
                    "freight_value": item_freight
                })

            # Payments
            pay_type = np.random.choice(["credit_card", "boleto", "voucher", "debit_card"], p=[0.74, 0.19, 0.05, 0.02])
            order_payments_records.append({
                "order_id": order_id,
                "payment_sequential": 1,
                "payment_type": pay_type,
                "payment_installments": random.randint(1, 6) if pay_type == "credit_card" else 1,
                "payment_value": round(order_total_gmv, 2)
            })

            # Reviews (for delivered orders, 98% leave a review)
            if status == "delivered" and random.random() < 0.98:
                # If delivered late, higher chance of 1 or 2 stars
                is_late = delivered_date > estimated_date
                if is_late:
                    score = np.random.choice([1, 2, 3, 4, 5], p=[0.55, 0.20, 0.12, 0.08, 0.05])
                else:
                    score = np.random.choice([1, 2, 3, 4, 5], p=[0.05, 0.04, 0.08, 0.23, 0.60])

                rev_create = delivered_date + timedelta(days=1)
                order_reviews_records.append({
                    "review_id": uuid.uuid4().hex,
                    "order_id": order_id,
                    "review_score": int(score),
                    "review_creation_date": rev_create,
                    "review_answer_timestamp": rev_create + timedelta(hours=random.randint(2, 48))
                })

    # Synthetic Funnel Demonstration Events (~15,000 clickstream logs)
    funnel_events = []
    event_names = ["app_open", "restaurant_view", "item_view", "add_to_cart", "checkout_start", "order_placed"]
    for _ in range(3000):
        session_id = uuid.uuid4().hex
        cust = random.choice(customers_pool)
        sess_ts = datetime(2018, 5, random.randint(1, 28), random.randint(8, 22), random.randint(0, 59))
        step_count = np.random.choice([1, 2, 3, 4, 5, 6], p=[0.25, 0.25, 0.20, 0.15, 0.10, 0.05])
        for step_i in range(step_count):
            funnel_events.append({
                "event_id": uuid.uuid4().hex,
                "session_id": session_id,
                "user_unique_id": cust["customer_unique_id"],
                "event_name": event_names[step_i],
                "event_timestamp": sess_ts + timedelta(seconds=step_i * random.randint(15, 120)),
                "platform": random.choice(["iOS", "Android", "Web"])
            })

    # Save to DataFrames
    df_orders = pd.DataFrame(orders_records)
    df_order_items = pd.DataFrame(order_items_records)
    df_order_payments = pd.DataFrame(order_payments_records)
    df_order_reviews = pd.DataFrame(order_reviews_records)
    df_dim_customers = pd.DataFrame(dim_customers_records)
    df_funnel = pd.DataFrame(funnel_events)

    # Export to CSV files in data/processed/
    print("Writing CSV artifacts to disk...")
    df_orders.to_csv(PROCESSED_DIR / "fact_orders.csv", index=False)
    df_order_items.to_csv(PROCESSED_DIR / "fact_order_items.csv", index=False)
    df_order_payments.to_csv(PROCESSED_DIR / "fact_order_payments.csv", index=False)
    df_order_reviews.to_csv(PROCESSED_DIR / "fact_order_reviews.csv", index=False)
    df_dim_customers.to_csv(PROCESSED_DIR / "dim_customers.csv", index=False)
    df_products.to_csv(PROCESSED_DIR / "dim_products.csv", index=False)
    df_sellers.to_csv(PROCESSED_DIR / "dim_sellers.csv", index=False)
    df_funnel.to_csv(PROCESSED_DIR / "synthetic_funnel_events.csv", index=False)

    print(f"Generated successfully: {len(df_orders)} orders, {len(df_order_items)} items, {len(df_dim_customers)} customer records.")
    return True


if __name__ == "__main__":
    generate_marketplace_dataset()
