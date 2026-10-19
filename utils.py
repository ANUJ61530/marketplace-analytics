"""Small helper: run a named query from sql/02_analysis.sql."""
import re
import sqlite3
from pathlib import Path

import pandas as pd

BASE = Path(__file__).parent
DB = BASE / "olist.db"


def load_queries():
    text = (BASE / "sql" / "02_analysis.sql").read_text()
    parts = re.split(r"^-- name: (\w+)\s*$", text, flags=re.M)
    return {parts[i]: parts[i + 1].strip() for i in range(1, len(parts), 2)}


def run(name):
    sql = load_queries()[name]
    with sqlite3.connect(DB) as con:
        return pd.read_sql_query(sql, con)
