"""
Streamlit Dashboard — Main Overview Page
Food Delivery Marketplace Analytics Platform

Run with: streamlit run dashboard/pages/01_overview.py
"""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(BASE_DIR))

from src.db_connect import get_engine

# Page config
st.set_page_config(
    page_title="Marketplace Analytics",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Title and description
st.title("🍕 Food Delivery Marketplace Analytics")
st.markdown("Real-time monitoring and deep-dive analysis of marketplace performance")

# Cache connection
@st.cache_resource
def get_db_engine():
    return get_engine()

@st.cache_data(ttl=300)
def load_orders_data():
    engine, _ = get_db_engine()
    with engine.connect() as conn:
        df_orders = pd.read_sql("SELECT * FROM fact_orders", conn)
        df_order_items = pd.read_sql("SELECT * FROM fact_order_items", conn)
        df_customers = pd.read_sql("SELECT * FROM dim_customers", conn)
    return df_orders, df_order_items, df_customers

# Load data
try:
    df_orders, df_order_items, df_customers = load_orders_data()
except Exception as e:
    st.error(f"❌ Database connection failed: {e}")
    st.info("💡 Have you run the data pipeline? Execute: python run_pipeline.py")
    st.stop()

# Prepare data
df_orders['order_purchase_timestamp'] = pd.to_datetime(df_orders['order_purchase_timestamp'])
df_orders['order_delivered_customer_date'] = pd.to_datetime(df_orders['order_delivered_customer_date'])

# Calculate order GMV
order_gmv = df_order_items.groupby('order_id').agg({
    'price': 'sum',
    'freight_value': 'sum'
}).reset_index()
order_gmv['order_gmv'] = order_gmv['price'] + order_gmv['freight_value']
df_orders = df_orders.merge(order_gmv, on='order_id', how='left')

# Filter delivered orders for KPIs
delivered = df_orders[df_orders['order_status'] == 'delivered'].copy()

# ============================================================================
# SIDEBAR FILTERS
# ============================================================================
st.sidebar.header("⚙️ Filters")

date_range = st.sidebar.date_input(
    "Select Date Range",
    value=(df_orders['order_purchase_timestamp'].min().date(),
           df_orders['order_purchase_timestamp'].max().date()),
    min_value=df_orders['order_purchase_timestamp'].min().date(),
    max_value=df_orders['order_purchase_timestamp'].max().date()
)

# Filter data by date range
mask = (df_orders['order_purchase_timestamp'].dt.date >= date_range[0]) & \
       (df_orders['order_purchase_timestamp'].dt.date <= date_range[1])
df_filtered = df_orders[mask].copy()
delivered_filtered = df_filtered[df_filtered['order_status'] == 'delivered'].copy()

# ============================================================================
# KEY METRICS (KPI Cards)
# ============================================================================
st.header("📈 Executive Dashboard")

col1, col2, col3, col4 = st.columns(4)

with col1:
    total_orders = len(df_filtered)
    st.metric(
        "Total Orders",
        f"{total_orders:,}",
        delta=f"{total_orders - df_filtered[df_filtered['order_status']=='canceled'].shape[0]:,} delivered"
    )

with col2:
    delivered_cnt = len(delivered_filtered)
    st.metric(
        "Delivered Orders",
        f"{delivered_cnt:,}",
        delta=f"{(delivered_cnt/total_orders*100):.1f}% of total"
    )

with col3:
    total_gmv = delivered_filtered['order_gmv'].sum()
    st.metric(
        "Total GMV",
        f"BRL {total_gmv:,.0f}",
        delta=f"R${total_gmv/1000:.1f}K"
    )

with col4:
    avg_order_value = delivered_filtered['order_gmv'].mean()
    st.metric(
        "Average Order Value",
        f"BRL {avg_order_value:.2f}",
        delta=f"per order"
    )

# ============================================================================
# CHARTS SECTION 1: Time Series
# ============================================================================
st.divider()
st.subheader("📊 Time Series Analysis")

col1, col2 = st.columns(2)

# Monthly Orders Trend
with col1:
    monthly_orders = df_filtered.groupby(df_filtered['order_purchase_timestamp'].dt.to_period('M')).size()
    monthly_orders.index = monthly_orders.index.to_timestamp()
    
    fig1 = px.line(
        x=monthly_orders.index,
        y=monthly_orders.values,
        markers=True,
        title="Orders per Month",
        labels={'x': 'Month', 'y': 'Order Count'},
        line_shape='linear'
    )
    fig1.update_traces(line_color='#2E86AB', marker_size=8)
    fig1.update_layout(height=400, template='plotly_white')
    st.plotly_chart(fig1, use_container_width=True)

# Monthly GMV Trend
with col2:
    monthly_gmv = delivered_filtered.groupby(delivered_filtered['order_purchase_timestamp'].dt.to_period('M'))['order_gmv'].sum()
    monthly_gmv.index = monthly_gmv.index.to_timestamp()
    
    fig2 = px.line(
        x=monthly_gmv.index,
        y=monthly_gmv.values / 1000,
        markers=True,
        title="GMV per Month (BRL Thousands)",
        labels={'x': 'Month', 'y': 'GMV (1000s)'},
        line_shape='linear'
    )
    fig2.update_traces(line_color='#A23B72', marker_size=8)
    fig2.update_layout(height=400, template='plotly_white')
    st.plotly_chart(fig2, use_container_width=True)

# ============================================================================
# CHARTS SECTION 2: Distribution & Status
# ============================================================================
st.divider()
st.subheader("📋 Order Status & Distribution")

col1, col2 = st.columns(2)

# Order Status Distribution
with col1:
    status_counts = df_filtered['order_status'].value_counts()
    colors = {'delivered': '#06A77D', 'canceled': '#E63946', 'shipped': '#F18F01', 'invoiced': '#2E86AB'}
    
    fig3 = px.pie(
        values=status_counts.values,
        names=status_counts.index,
        title="Order Status Distribution",
        color_discrete_map=colors
    )
    fig3.update_layout(height=400)
    st.plotly_chart(fig3, use_container_width=True)

# AOV Trend
with col2:
    daily_aov = delivered_filtered.groupby(delivered_filtered['order_purchase_timestamp'].dt.date)['order_gmv'].mean()
    
    fig4 = px.line(
        x=daily_aov.index,
        y=daily_aov.values,
        title="Average Order Value — Daily Trend",
        labels={'x': 'Date', 'y': 'AOV (BRL)'},
        line_shape='linear'
    )
    fig4.update_traces(line_color='#F18F01', line_width=2)
    fig4.update_layout(height=400, template='plotly_white')
    st.plotly_chart(fig4, use_container_width=True)

# ============================================================================
# CUSTOMER INSIGHTS
# ============================================================================
st.divider()
st.subheader("👥 Customer Insights")

col1, col2 = st.columns(2)

with col1:
    unique_customers = df_filtered['customer_id'].nunique()
    total_customers = df_customers['customer_unique_id'].nunique()
    st.metric(
        "Active Customers (Period)",
        f"{unique_customers:,}",
        delta=f"{(unique_customers/total_customers*100):.1f}% of total"
    )

with col2:
    repeat_orders = df_filtered.groupby('customer_id')['order_id'].count()
    repeat_rate = (repeat_orders > 1).sum() / len(repeat_orders) * 100
    st.metric(
        "Repeat Purchase Rate",
        f"{repeat_rate:.1f}%",
        delta="customers with 2+ orders"
    )

# ============================================================================
# DATA QUALITY MONITORING
# ============================================================================
st.divider()
st.subheader("✅ Data Quality Metrics")

col1, col2, col3 = st.columns(3)

with col1:
    missing_gmv = df_filtered['order_gmv'].isnull().sum()
    st.metric(
        "Missing GMV Records",
        f"{missing_gmv}",
        delta="out of " + str(len(df_filtered))
    )

with col2:
    missing_dates = df_filtered['order_delivered_customer_date'].isnull().sum()
    st.metric(
        "Pending Deliveries",
        f"{missing_dates}",
        delta="orders not yet delivered"
    )

with col3:
    data_freshness = (datetime.now() - df_filtered['order_purchase_timestamp'].max()).days
    st.metric(
        "Data Freshness",
        f"{data_freshness} days",
        delta="since latest order"
    )

# ============================================================================
# DATA TABLE PREVIEW
# ============================================================================
st.divider()
st.subheader("📋 Recent Orders (Sample)")

display_cols = ['order_id', 'customer_id', 'order_status', 'order_purchase_timestamp', 'order_gmv']
sample_data = df_filtered[display_cols].head(10)
sample_data['order_purchase_timestamp'] = sample_data['order_purchase_timestamp'].dt.strftime('%Y-%m-%d %H:%M')
sample_data['order_gmv'] = sample_data['order_gmv'].apply(lambda x: f"BRL {x:.2f}")

st.dataframe(sample_data, use_container_width=True, hide_index=True)

# ============================================================================
# FOOTER
# ============================================================================
st.divider()
st.markdown("""
---
**Navigation:** Use the sidebar to explore different analysis views:
- 📊 **Metrics Dashboard**: Detailed KPI metrics
- 🔍 **Revenue RCA**: Root cause analysis of revenue 
- 📈 **Geographic Analysis**: Performance by region

**Last Updated:** """ + datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
