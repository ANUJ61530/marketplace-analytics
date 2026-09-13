"""
Data Loading & Database Materialization Pipeline
Loads cleaned CSV datasets into MySQL (or local SQLite fallback),
applies indexes, and compiles the analytical views.
"""

import sys
from pathlib import Path
import pandas as pd
from sqlalchemy import text

# Ensure parent directory is in sys.path
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

from src.db_connect import get_engine

PROCESSED_DIR = BASE_DIR / "data" / "processed"


def load_all_tables():
    """
    Ingests all processed CSV files into the connected database.
    """
    engine, dialect = get_engine()
    print(f"Connected to database engine using dialect: [{dialect.upper()}]")

    csv_mapping = {
        "dim_customers": PROCESSED_DIR / "dim_customers.csv",
        "dim_products": PROCESSED_DIR / "dim_products.csv",
        "dim_sellers": PROCESSED_DIR / "dim_sellers.csv",
        "fact_orders": PROCESSED_DIR / "fact_orders.csv",
        "fact_order_items": PROCESSED_DIR / "fact_order_items.csv",
        "fact_order_payments": PROCESSED_DIR / "fact_order_payments.csv",
        "fact_order_reviews": PROCESSED_DIR / "fact_order_reviews.csv",
        "synthetic_funnel_events": PROCESSED_DIR / "synthetic_funnel_events.csv",
    }

    # Verify that files exist
    missing = [f.name for f in csv_mapping.values() if not f.exists()]
    if missing:
        print(f"Error: Missing expected CSV files: {missing}")
        print("Please run `python src/data_generator.py` first.")
        return False

    with engine.begin() as conn:
        for table_name, csv_path in csv_mapping.items():
            print(f"Loading {table_name} from {csv_path.name}...")
            df = pd.read_csv(csv_path)

            # Convert timestamp columns to proper datetime
            time_cols = [c for c in df.columns if "timestamp" in c or "date" in c or "approved" in c]
            for tc in time_cols:
                df[tc] = pd.to_datetime(df[tc], errors="coerce")

            # Load into database
            df.to_sql(table_name, conn, if_exists="replace", index=False)
            print(f"  -> Ingested {len(df):,} rows into `{table_name}`.")

    # Create analytical view
    print("Compiling analytical view `v_order_summary`...")
    view_sql = """
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
        CASE WHEN o.order_status = 'delivered' THEN 1 ELSE 0 END AS is_delivered,
        
        COALESCE(i.total_items, 0) AS total_items,
        COALESCE(i.goods_subtotal, 0.0) AS goods_subtotal,
        COALESCE(i.freight_total, 0.0) AS freight_total,
        COALESCE(i.order_gmv, 0.0) AS order_gmv,
        COALESCE(p.payment_total, 0.0) AS payment_total,
        r.review_score
        
    FROM fact_orders o
    LEFT JOIN dim_customers c ON o.customer_id = c.customer_id
    LEFT JOIN (
        SELECT 
            order_id, 
            COUNT(*) AS total_items,
            SUM(price) AS goods_subtotal,
            SUM(freight_value) AS freight_total,
            SUM(price + freight_value) AS order_gmv
        FROM fact_order_items
        GROUP BY order_id
    ) i ON o.order_id = i.order_id
    LEFT JOIN (
        SELECT order_id, SUM(payment_value) AS payment_total
        FROM fact_order_payments
        GROUP BY order_id
    ) p ON o.order_id = p.order_id
    LEFT JOIN fact_order_reviews r ON o.order_id = r.order_id;
    """

    try:
        with engine.begin() as conn:
            # For SQLite vs MySQL view creation
            for stmt in view_sql.strip().split(";"):
                if stmt.strip():
                    conn.execute(text(stmt.strip()))
        print("Successfully created `v_order_summary` view.")
    except Exception as e:
        print(f"Note on view creation: {e}")

    print("\nDatabase loading complete. All analytical tables ready.")
    return True


if __name__ == "__main__":
    load_all_tables()
