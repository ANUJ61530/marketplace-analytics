"""One-page dashboard on top of olist.db.  Run: streamlit run dashboard/app.py"""
import sqlite3
from pathlib import Path

import pandas as pd
import streamlit as st

DB = Path(__file__).resolve().parent.parent / "olist.db"

st.set_page_config(page_title="Olist delivery dashboard", layout="wide")
st.title("Delivery performance and reviews")
st.caption("Real Olist marketplace orders, 2017 to Aug 2018 (a marketplace, not a food delivery company).")


@st.cache_data
def query(sql, params=()):
    with sqlite3.connect(DB) as con:
        return pd.read_sql_query(sql, con, params=params)


states = query("SELECT DISTINCT state FROM order_facts ORDER BY state")["state"].tolist()
chosen = st.sidebar.multiselect("State", states, default=states)
if not chosen:
    st.warning("Pick at least one state.")
    st.stop()
marks = ",".join("?" * len(chosen))

# Delivered orders in the period with a delivery date, in the chosen states
base = f"""
    FROM order_facts
    WHERE state IN ({marks}) AND delivery_days IS NOT NULL
      AND month BETWEEN '2017-01' AND '2018-08'
"""

kpi = query(f"""
    SELECT COUNT(*) AS orders, ROUND(SUM(gmv)) AS gmv,
           ROUND(AVG(delivery_days), 1) AS days,
           ROUND(100.0 * AVG(is_late), 1) AS late_pct,
           ROUND(AVG(review_score), 2) AS review
    {base}""", chosen).iloc[0]

c1, c2, c3, c4, c5 = st.columns(5)
c1.metric("Delivered orders", f"{int(kpi.orders):,}")
c2.metric("GMV (BRL)", f"{kpi.gmv:,.0f}")
c3.metric("Avg delivery days", kpi.days)
c4.metric("Late deliveries", f"{kpi.late_pct}%")
c5.metric("Avg review", kpi.review)

left, right = st.columns(2)

with left:
    st.subheader("Orders per month")
    monthly = query(f"SELECT month, COUNT(*) AS orders {base} GROUP BY month ORDER BY month", chosen)
    st.bar_chart(monthly, x="month", y="orders")

    st.subheader("Late deliveries by month (%)")
    late = query(f"SELECT month, ROUND(100.0 * AVG(is_late), 1) AS late_pct {base} GROUP BY month ORDER BY month", chosen)
    st.line_chart(late, x="month", y="late_pct")

with right:
    st.subheader("Review score by delivery lateness")
    buckets = query(f"""
        SELECT CASE WHEN days_vs_promise <= 0 THEN '1 On time'
                    WHEN days_vs_promise <= 3 THEN '2 1-3 days late'
                    WHEN days_vs_promise <= 7 THEN '3 4-7 days late'
                    ELSE '4 8+ days late' END AS bucket,
               ROUND(AVG(review_score), 2) AS avg_review, COUNT(*) AS orders
        {base} AND review_score IS NOT NULL
        GROUP BY bucket ORDER BY bucket""", chosen)
    st.bar_chart(buckets, x="bucket", y="avg_review")
    st.dataframe(buckets, hide_index=True, width="stretch")

    st.subheader("Slowest states (min. 300 delivered orders in selection)")
    by_state = query(f"""
        SELECT state, COUNT(*) AS orders, ROUND(AVG(delivery_days), 1) AS avg_days,
               ROUND(100.0 * AVG(is_late), 1) AS late_pct
        {base} GROUP BY state HAVING COUNT(*) >= 300 ORDER BY late_pct DESC LIMIT 8""", chosen)
    st.dataframe(by_state, hide_index=True, width="stretch")
