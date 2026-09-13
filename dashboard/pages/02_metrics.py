"""
Streamlit Dashboard — Metrics Analysis Page
Detailed marketplace KPIs and performance metrics
"""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(BASE_DIR))

from src.db_connect import get_engine

st.set_page_config(
    page_title="Metrics Dashboard",
    page_icon="📊",
    layout="wide"
)

st.title("📊 Marketplace Metrics Dashboard")
st.markdown("Comprehensive KPI analysis and performance tracking")

# Cache functions
@st.cache_resource
def get_db_engine():
    return get_engine()

@st.cache_data(ttl=300)
def load_analytics_data():
    engine, _ = get_db_engine()
    with engine.connect() as conn:
        df_orders = pd.read_sql("SELECT * FROM fact_orders", conn)
        df_order_items = pd.read_sql("SELECT * FROM fact_order_items", conn)
        df_customers = pd.read_sql("SELECT * FROM dim_customers", conn)
        df_reviews = pd.read_sql("SELECT * FROM fact_order_reviews", conn)
    return df_orders, df_order_items, df_customers, df_reviews

# Load data
try:
    df_orders, df_order_items, df_customers, df_reviews = load_analytics_data()
except Exception as e:
    st.error(f"Database connection failed: {e}")
    st.stop()

# Prepare data
df_orders['order_purchase_timestamp'] = pd.to_datetime(df_orders['order_purchase_timestamp'])
df_orders['order_delivered_customer_date'] = pd.to_datetime(df_orders['order_delivered_customer_date'])

order_gmv = df_order_items.groupby('order_id').agg({
    'price': 'sum',
    'freight_value': 'sum'
}).reset_index()
order_gmv['order_gmv'] = order_gmv['price'] + order_gmv['freight_value']
df_orders = df_orders.merge(order_gmv, on='order_id', how='left')

delivered = df_orders[df_orders['order_status'] == 'delivered'].copy()

# Sidebar date filter
st.sidebar.header("⚙️ Filters")
date_range = st.sidebar.date_input(
    "Select Date Range",
    value=(df_orders['order_purchase_timestamp'].min().date(),
           df_orders['order_purchase_timestamp'].max().date())
)

mask = (df_orders['order_purchase_timestamp'].dt.date >= date_range[0]) & \
       (df_orders['order_purchase_timestamp'].dt.date <= date_range[1])
df_filtered = df_orders[mask].copy()
delivered_filtered = df_filtered[df_filtered['order_status'] == 'delivered'].copy()

# ============================================================================
# MONTHLY KPI SCORECARD
# ============================================================================
st.header("📈 Monthly KPI Scorecard")

# Prepare monthly data
df_filtered['order_month'] = df_filtered['order_purchase_timestamp'].dt.to_period('M').astype(str)
delivered_filtered['order_month'] = delivered_filtered['order_purchase_timestamp'].dt.to_period('M').astype(str)

monthly_kpis = delivered_filtered.groupby('order_month').agg({
    'order_id': 'count',
    'customer_id': 'nunique',
    'order_gmv': ['sum', 'mean']
}).round(2)

monthly_kpis.columns = ['orders', 'customers', 'total_gmv', 'aov']
monthly_kpis = monthly_kpis.reset_index()

st.dataframe(monthly_kpis, use_container_width=True, hide_index=True)

# ============================================================================
# PERFORMANCE CHARTS
# ============================================================================
st.divider()
st.subheader("📊 Key Metrics Trends")

col1, col2 = st.columns(2)

# Orders and Customers
with col1:
    fig1 = go.Figure()
    fig1.add_trace(go.Scatter(
        x=monthly_kpis['order_month'],
        y=monthly_kpis['orders'],
        name='Orders',
        mode='lines+markers',
        line=dict(color='#2E86AB', width=3),
        marker=dict(size=8)
    ))
    fig1.update_layout(
        title='Orders and Customers per Month',
        xaxis_title='Month',
        yaxis_title='Orders',
        height=400,
        template='plotly_white'
    )
    st.plotly_chart(fig1, use_container_width=True)

# GMV and AOV
with col2:
    fig2 = go.Figure()
    fig2.add_trace(go.Bar(
        x=monthly_kpis['order_month'],
        y=monthly_kpis['total_gmv'] / 1000,
        name='Total GMV',
        marker=dict(color='#A23B72')
    ))
    fig2.add_trace(go.Scatter(
        x=monthly_kpis['order_month'],
        y=monthly_kpis['aov'],
        name='AOV',
        yaxis='y2',
        mode='lines+markers',
        line=dict(color='#F18F01', width=3),
        marker=dict(size=8)
    ))
    fig2.update_layout(
        title='GMV and AOV Trends',
        xaxis_title='Month',
        yaxis=dict(title='GMV (1000s BRL)'),
        yaxis2=dict(title='AOV (BRL)', overlaying='y', side='right'),
        height=400,
        template='plotly_white'
    )
    st.plotly_chart(fig2, use_container_width=True)

# ============================================================================
# PRODUCT CATEGORY ANALYSIS
# ============================================================================
st.divider()
st.subheader("🏪 Product Category Performance")

df_products = pd.read_sql("SELECT * FROM dim_products", con=get_db_engine()[0].connect())
cat_items = df_order_items.merge(df_products[['product_id', 'category_name_english']], on='product_id', how='left')
cat_items = cat_items.merge(df_filtered[['order_id', 'order_status']], on='order_id', how='left')
delivered_items = cat_items[cat_items['order_status'] == 'delivered'].copy()

category_metrics = delivered_items.groupby('category_name_english').agg({
    'order_id': 'count',
    'price': 'sum',
    'freight_value': 'sum'
}).reset_index()

category_metrics['total_gmv'] = category_metrics['price'] + category_metrics['freight_value']
category_metrics = category_metrics.sort_values('order_id', ascending=False).head(12)
category_metrics.columns = ['category', 'items_sold', 'goods_value', 'freight_value', 'total_gmv']

col1, col2 = st.columns(2)

with col1:
    fig3 = px.bar(
        category_metrics,
        x='items_sold',
        y='category',
        orientation='h',
        title='Top Categories by Item Volume',
        labels={'items_sold': 'Items Sold', 'category': 'Category'},
        color='items_sold',
        color_continuous_scale='Blues'
    )
    fig3.update_layout(height=500, showlegend=False)
    st.plotly_chart(fig3, use_container_width=True)

with col2:
    fig4 = px.bar(
        category_metrics,
        x='total_gmv',
        y='category',
        orientation='h',
        title='Top Categories by GMV',
        labels={'total_gmv': 'GMV (BRL)', 'category': 'Category'},
        color='total_gmv',
        color_continuous_scale='Reds'
    )
    fig4.update_layout(height=500, showlegend=False)
    st.plotly_chart(fig4, use_container_width=True)

# ============================================================================
# DELIVERY PERFORMANCE
# ============================================================================
st.divider()
st.subheader("🚚 Delivery Performance")

delivered_orders = delivered_filtered.copy()
delivered_orders['days_to_deliver'] = (delivered_orders['order_delivered_customer_date'] - 
                                       delivered_orders['order_purchase_timestamp']).dt.days
delivered_orders['is_on_time'] = (delivered_orders['order_delivered_customer_date'] <= 
                                  delivered_orders['order_estimated_delivery_date'])

on_time_pct = delivered_orders['is_on_time'].sum() / len(delivered_orders) * 100
avg_days = delivered_orders['days_to_deliver'].mean()

col1, col2, col3 = st.columns(3)

with col1:
    st.metric("On-Time Delivery Rate", f"{on_time_pct:.1f}%")

with col2:
    st.metric("Avg Days to Delivery", f"{avg_days:.1f} days")

with col3:
    st.metric("Total Delivered Orders", f"{len(delivered_orders):,}")

# Delivery time distribution
fig5 = px.histogram(
    delivered_orders,
    x='days_to_deliver',
    nbins=25,
    title='Distribution of Delivery Times',
    labels={'days_to_deliver': 'Days to Deliver', 'count': 'Frequency'},
    color_discrete_sequence=['#06A77D']
)
fig5.add_vline(x=avg_days, line_dash="dash", line_color="red", 
              annotation_text=f"Mean: {avg_days:.1f}d", annotation_position="top right")
fig5.update_layout(height=400, template='plotly_white')
st.plotly_chart(fig5, use_container_width=True)

# ============================================================================
# CUSTOMER QUALITY METRICS
# ============================================================================
st.divider()
st.subheader("⭐ Customer & Review Metrics")

col1, col2 = st.columns(2)

with col1:
    # Review statistics
    if len(df_reviews) > 0:
        avg_score = df_reviews['review_score'].mean()
        st.metric("Average Review Score", f"{avg_score:.2f} / 5.0")
        
        fig6 = px.bar(
            df_reviews['review_score'].value_counts().sort_index(),
            title='Review Score Distribution',
            labels={'index': 'Score', 'value': 'Count'},
            color_discrete_sequence=['#E63946', '#F77F00', '#FCBF49', '#D3E34F', '#06A77D']
        )
        st.plotly_chart(fig6, use_container_width=True)
    else:
        st.info("No review data available yet")

with col2:
    # Customer repeat behavior
    repeat_orders = df_filtered.groupby('customer_id')['order_id'].count()
    repeat_dist = repeat_orders.value_counts().sort_index().head(10)
    
    fig7 = px.bar(
        x=repeat_dist.index,
        y=repeat_dist.values,
        title='Customer Order Frequency Distribution',
        labels={'x': 'Orders per Customer', 'y': 'Number of Customers'},
        color_discrete_sequence=['#2E86AB']
    )
    fig7.update_layout(height=400, template='plotly_white')
    st.plotly_chart(fig7, use_container_width=True)

# ============================================================================
# DETAILED METRICS TABLE
# ============================================================================
st.divider()
st.subheader("📋 Detailed Metrics Table")

detailed_metrics = pd.DataFrame({
    'Metric': [
        'Total Orders',
        'Delivered Orders',
        'Canceled Orders',
        'Total GMV',
        'Average Order Value',
        'Total Goods Value',
        'Total Freight Value',
        'Unique Customers',
        'Orders per Customer',
        'Customer LTV'
    ],
    'Value': [
        f"{len(df_filtered):,}",
        f"{len(delivered_filtered):,}",
        f"{len(df_filtered[df_filtered['order_status'] == 'canceled']):,}",
        f"BRL {delivered_filtered['order_gmv'].sum():,.2f}",
        f"BRL {delivered_filtered['order_gmv'].mean():.2f}",
        f"BRL {order_gmv['price'].sum():,.2f}",
        f"BRL {order_gmv['freight_value'].sum():,.2f}",
        f"{df_filtered['customer_id'].nunique():,}",
        f"{len(df_filtered) / df_filtered['customer_id'].nunique():.2f}",
        f"BRL {delivered_filtered['order_gmv'].sum() / delivered_filtered['customer_id'].nunique():.2f}"
    ]
})

st.dataframe(detailed_metrics, use_container_width=True, hide_index=True)
