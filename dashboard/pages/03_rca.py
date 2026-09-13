"""
Streamlit Dashboard — Revenue RCA Page
Root Cause Analysis with mathematical decomposition
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
    page_title="Revenue RCA",
    page_icon="🔍",
    layout="wide"
)

st.title("🔍 Revenue Root Cause Analysis")
st.markdown("Three-factor decomposition: **GMV = Users × Frequency × AOV**")

# Cache functions
@st.cache_resource
def get_db_engine():
    return get_engine()

@st.cache_data(ttl=300)
def load_rca_data():
    engine, _ = get_db_engine()
    with engine.connect() as conn:
        df_orders = pd.read_sql("SELECT * FROM fact_orders", conn)
        df_order_items = pd.read_sql("SELECT * FROM fact_order_items", conn)
        df_customers = pd.read_sql("SELECT * FROM dim_customers", conn)
        df_products = pd.read_sql("SELECT * FROM dim_products", conn)
    return df_orders, df_order_items, df_customers, df_products

# Load data
try:
    df_orders, df_order_items, df_customers, df_products = load_rca_data()
except Exception as e:
    st.error(f"Database connection failed: {e}")
    st.stop()

# Prepare data
df_orders['order_purchase_timestamp'] = pd.to_datetime(df_orders['order_purchase_timestamp'])

order_gmv = df_order_items.groupby('order_id').agg({
    'price': 'sum',
    'freight_value': 'sum'
}).reset_index()
order_gmv['order_gmv'] = order_gmv['price'] + order_gmv['freight_value']

df_orders = df_orders.merge(order_gmv, on='order_id', how='left')
df_orders = df_orders.merge(df_customers[['customer_id', 'customer_unique_id']], on='customer_id', how='left')

# Filter delivered orders
delivered = df_orders[df_orders['order_status'] == 'delivered'].copy()
delivered['order_month'] = delivered['order_purchase_timestamp'].dt.strftime('%Y-%m')

# ============================================================================
# PERIOD SELECTION
# ============================================================================
st.sidebar.header("⚙️ RCA Configuration")

# Get available months
available_months = sorted(delivered['order_month'].unique())

# Default: Last two months
if len(available_months) >= 2:
    default_t0_idx = len(available_months) - 2
    default_t1_idx = len(available_months) - 1
else:
    default_t0_idx = 0
    default_t1_idx = min(1, len(available_months) - 1)

t0_month = st.sidebar.selectbox(
    "Baseline Month (T0)",
    options=available_months,
    index=default_t0_idx,
    key="t0"
)

t1_month = st.sidebar.selectbox(
    "Comparison Month (T1)",
    options=available_months,
    index=default_t1_idx,
    key="t1"
)

# Extract period data
t0_data = delivered[delivered['order_month'] == t0_month]
t1_data = delivered[delivered['order_month'] == t1_month]

# Calculate metrics for both periods
def calculate_metrics(data):
    active_users = data['customer_unique_id'].nunique()
    total_orders = len(data)
    total_gmv = data['order_gmv'].sum()
    
    if active_users > 0:
        order_frequency = total_orders / active_users
    else:
        order_frequency = 0
    
    if total_orders > 0:
        aov = total_gmv / total_orders
    else:
        aov = 0
    
    return {
        'active_users': active_users,
        'total_orders': total_orders,
        'total_gmv': total_gmv,
        'order_frequency': order_frequency,
        'aov': aov
    }

t0_metrics = calculate_metrics(t0_data)
t1_metrics = calculate_metrics(t1_data)

# ============================================================================
# DECOMPOSITION ANALYSIS
# ============================================================================
st.header(f"📊 Comparing {t0_month} (T0) vs {t1_month} (T1)")

# Extract key values
u0, f0, aov0, gmv0 = t0_metrics['active_users'], t0_metrics['order_frequency'], t0_metrics['aov'], t0_metrics['total_gmv']
u1, f1, aov1, gmv1 = t1_metrics['active_users'], t1_metrics['order_frequency'], t1_metrics['aov'], t1_metrics['total_gmv']

# Calculate changes
delta_u = u1 - u0
delta_f = f1 - f0
delta_aov = aov1 - aov0
delta_gmv = gmv1 - gmv0

pct_u_change = (delta_u / u0 * 100) if u0 > 0 else 0
pct_f_change = (delta_f / f0 * 100) if f0 > 0 else 0
pct_aov_change = (delta_aov / aov0 * 100) if aov0 > 0 else 0
pct_gmv_change = (delta_gmv / gmv0 * 100) if gmv0 > 0 else 0

# Display metrics in columns
col1, col2, col3 = st.columns(3)

with col1:
    st.metric(
        f"Average Order Value",
        f"BRL {aov1:.2f}",
        delta=f"BRL {delta_aov:.2f} ({pct_aov_change:+.1f}%)",
        delta_color="inverse"
    )

with col2:
    st.metric(
        f"Order Frequency",
        f"{f1:.3f} orders/user",
        delta=f"{delta_f:+.3f} ({pct_f_change:+.1f}%)",
        delta_color="inverse"
    )

with col3:
    st.metric(
        f"Active Users",
        f"{u1:,.0f}",
        delta=f"{delta_u:+,.0f} ({pct_u_change:+.1f}%)",
        delta_color="inverse"
    )

# ============================================================================
# KEY FINDING: OVERALL GMV CHANGE
# ============================================================================
st.divider()
if delta_gmv < 0:
    st.error(f"⚠️ **REVENUE DECLINE**: GMV decreased by BRL {abs(delta_gmv):,.2f} ({pct_gmv_change:.2f}%)")
elif delta_gmv > 0:
    st.success(f"✅ **REVENUE GROWTH**: GMV increased by BRL {delta_gmv:,.2f} ({pct_gmv_change:.2f}%)")
else:
    st.info(f"⚪ **NO CHANGE**: GMV remained stable")

# ============================================================================
# CONTRIBUTION ANALYSIS
# ============================================================================
st.subheader("📈 Factor Impact Analysis")

# Calculate individual contributions using additive decomposition
user_contribution = delta_u * f0 * aov0
freq_contribution = u1 * delta_f * aov0
aov_contribution = u1 * f1 * delta_aov

# Create visualization data
impact_data = pd.DataFrame({
    'Factor': ['User Volume', 'Order Frequency', 'AOV', 'Total Impact'],
    'GMV Change (BRL)': [user_contribution, freq_contribution, aov_contribution, delta_gmv],
    'Pct of Change': [
        (user_contribution / delta_gmv * 100) if delta_gmv != 0 else 0,
        (freq_contribution / delta_gmv * 100) if delta_gmv != 0 else 0,
        (aov_contribution / delta_gmv * 100) if delta_gmv != 0 else 0,
        100.0
    ]
})

col1, col2 = st.columns(2)

with col1:
    fig1 = px.bar(
        impact_data[:-1],  # Exclude total
        x='Factor',
        y='GMV Change (BRL)',
        title='GMV Impact by Factor',
        color='GMV Change (BRL)',
        color_continuous_scale='RdYlGn_r',
        hover_data={'GMV Change (BRL)': ':.0f'}
    )
    fig1.add_hline(y=0, line_dash="dash", line_color="gray")
    fig1.update_layout(height=400, showlegend=False)
    st.plotly_chart(fig1, use_container_width=True)

with col2:
    fig2 = px.pie(
        impact_data[:-1],
        values='GMV Change (BRL)',
        names='Factor',
        title='% Contribution to GMV Change',
        color_discrete_sequence=['#E63946', '#F77F00', '#FCBF49']
    )
    fig2.update_layout(height=400)
    st.plotly_chart(fig2, use_container_width=True)

# ============================================================================
# DETAILED COMPARISON TABLE
# ============================================================================
st.divider()
st.subheader("📊 Detailed Metric Comparison")

comparison_table = pd.DataFrame({
    'Metric': [
        'Active Users',
        'Total Orders',
        'Total GMV (BRL)',
        'Order Frequency (orders/user)',
        'AOV (BRL)',
        'Revenue per Customer (BRL)'
    ],
    t0_month: [
        f"{u0:,.0f}",
        f"{t0_metrics['total_orders']:,.0f}",
        f"{gmv0:,.2f}",
        f"{f0:.3f}",
        f"{aov0:.2f}",
        f"{gmv0/u0:.2f}" if u0 > 0 else "N/A"
    ],
    t1_month: [
        f"{u1:,.0f}",
        f"{t1_metrics['total_orders']:,.0f}",
        f"{gmv1:,.2f}",
        f"{f1:.3f}",
        f"{aov1:.2f}",
        f"{gmv1/u1:.2f}" if u1 > 0 else "N/A"
    ],
    'Change': [
        f"{delta_u:+,.0f} ({pct_u_change:+.1f}%)",
        f"{t1_metrics['total_orders'] - t0_metrics['total_orders']:+,.0f}",
        f"{delta_gmv:+,.2f} ({pct_gmv_change:+.1f}%)",
        f"{delta_f:+.3f} ({pct_f_change:+.1f}%)",
        f"{delta_aov:+.2f} ({pct_aov_change:+.1f}%)",
        f"{(gmv1/u1 - gmv0/u0):+.2f}" if u0 > 0 and u1 > 0 else "N/A"
    ]
})

st.dataframe(comparison_table, use_container_width=True, hide_index=True)

# ============================================================================
# GEOGRAPHIC SEGMENT ANALYSIS
# ============================================================================
st.divider()
st.subheader("🗺️ Geographic Segment Impact")

# Merge geographic data
geo_data = df_orders.merge(df_customers[['customer_id', 'customer_state']], on='customer_id', how='left')
geo_delivered = geo_data[geo_data['order_status'] == 'delivered'].copy()
geo_delivered['order_month'] = geo_delivered['order_purchase_timestamp'].dt.strftime('%Y-%m')

# By state analysis
t0_states = geo_delivered[geo_delivered['order_month'] == t0_month].groupby('customer_state')['order_gmv'].sum()
t1_states = geo_delivered[geo_delivered['order_month'] == t1_month].groupby('customer_state')['order_gmv'].sum()

geo_comparison = pd.DataFrame({
    'State': sorted(set(list(t0_states.index) + list(t1_states.index))),
})
geo_comparison['GMV_T0'] = geo_comparison['State'].map(lambda x: t0_states.get(x, 0))
geo_comparison['GMV_T1'] = geo_comparison['State'].map(lambda x: t1_states.get(x, 0))
geo_comparison['Change'] = geo_comparison['GMV_T1'] - geo_comparison['GMV_T0']
geo_comparison['Pct_Change'] = (geo_comparison['Change'] / geo_comparison['GMV_T0'] * 100).fillna(0)

top_impact_states = geo_comparison.nsmallest(5, 'Change')

fig3 = px.barh(
    top_impact_states,
    x='Change',
    y='State',
    title='Top 5 States with Largest GMV Decline',
    labels={'State': 'State', 'Change': 'GMV Change (BRL)'},
    color='Change',
    color_continuous_scale='Reds'
)
fig3.update_layout(height=350, template='plotly_white')
st.plotly_chart(fig3, use_container_width=True)

# ============================================================================
# CATEGORY ANALYSIS
# ============================================================================
st.divider()
st.subheader("🏪 Product Category Impact")

cat_items = df_order_items.merge(df_products[['product_id', 'category_name_english']], on='product_id', how='left')
cat_items = cat_items.merge(df_orders[['order_id', 'order_status', 'order_month']], on='order_id', how='left')
cat_delivered = cat_items[cat_items['order_status'] == 'delivered'].copy()

t0_cats = cat_delivered[cat_delivered['order_month'] == t0_month].groupby('category_name_english').apply(
    lambda x: (x['price'] + x['freight_value']).sum()
)
t1_cats = cat_delivered[cat_delivered['order_month'] == t1_month].groupby('category_name_english').apply(
    lambda x: (x['price'] + x['freight_value']).sum()
)

cat_comparison = pd.DataFrame({
    'Category': sorted(set(list(t0_cats.index) + list(t1_cats.index))),
})
cat_comparison['GMV_T0'] = cat_comparison['Category'].map(lambda x: t0_cats.get(x, 0))
cat_comparison['GMV_T1'] = cat_comparison['Category'].map(lambda x: t1_cats.get(x, 0))
cat_comparison['Change'] = cat_comparison['GMV_T1'] - cat_comparison['GMV_T0']

top_cat_impact = cat_comparison.nsmallest(8, 'Change')

fig4 = px.barh(
    top_cat_impact,
    x='Change',
    y='Category',
    title='Top 8 Categories with Largest GMV Decline',
    labels={'Category': 'Category', 'Change': 'GMV Change (BRL)'},
    color='Change',
    color_continuous_scale='Reds'
)
fig4.update_layout(height=400, template='plotly_white')
st.plotly_chart(fig4, use_container_width=True)

# ============================================================================
# SUMMARY & RECOMMENDATIONS
# ============================================================================
st.divider()
st.subheader("💡 Insights & Recommendations")

# Determine primary driver
effects = {
    'User Volume': abs(user_contribution),
    'Order Frequency': abs(freq_contribution),
    'AOV': abs(aov_contribution)
}
primary_driver = max(effects, key=effects.get)

col1, col2 = st.columns(2)

with col1:
    st.markdown(f"""
    ### 🎯 Key Finding
    
    **Primary Driver:** {primary_driver}
    - Contribution: BRL {effects[primary_driver]:,.2f}
    - % of GMV Change: {(effects[primary_driver]/abs(delta_gmv)*100):.1f}%
    """)

with col2:
    st.markdown(f"""
    ### 📋 Summary
    
    - **Period Comparison**: {t0_month} → {t1_month}
    - **GMV Change**: {pct_gmv_change:+.1f}%
    - **User Impact**: {pct_u_change:+.1f}%
    - **Frequency Impact**: {pct_f_change:+.1f}%
    - **AOV Impact**: {pct_aov_change:+.1f}%
    """)

st.markdown("""
### 🚀 Recommended Actions

1. **Address Primary Driver**: Focus mitigation efforts on the largest impact factor
2. **Geographic Targeting**: Run campaigns in weak-performing states
3. **Category Review**: Investigate declining categories for pricing/supply issues
4. **Customer Retention**: Implement loyalty programs if frequency is declining
""")
