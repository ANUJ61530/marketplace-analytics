"""Load the raw Olist CSVs into SQLite and build the order_facts table.

Run once:  python build_db.py
"""
import sqlite3
from pathlib import Path

import pandas as pd

BASE = Path(__file__).parent
RAW = BASE / "data" / "raw"
DB = BASE / "olist.db"

TABLES = {
    "customers": "olist_customers_dataset.csv",
    "orders": "olist_orders_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
    "products": "olist_products_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
}


def main():
    if DB.exists():
        DB.unlink()
    con = sqlite3.connect(DB)
    for name, csv in TABLES.items():
        df = pd.read_csv(RAW / csv)
        df.to_sql(name, con, index=False)
        print(f"{name:22s} {len(df):>8,} rows")
    con.executescript((BASE / "sql" / "01_order_facts.sql").read_text())
    n = con.execute("SELECT COUNT(*) FROM order_facts").fetchone()[0]
    print(f"{'order_facts':22s} {n:>8,} rows")
    con.close()


if __name__ == "__main__":
    main()
