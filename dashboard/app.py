"""
Streamlit Dashboard — Main Entry Point
Food Delivery Marketplace Analytics Platform

Run with: streamlit run dashboard/app.py
"""

import streamlit as st

st.set_page_config(
    page_title="Marketplace Analytics Platform",
    page_icon="📊"  # Main app
    layout="wide"
)

st.title("🍕 Food Delivery Marketplace Analytics Platform")

st.markdown("""
Welcome to the comprehensive analytics platform for monitoring and analyzing 
food delivery marketplace performance. Use the sidebar navigation to explore 
different analytical views.

## Available Dashboards

### 1. **Overview Dashboard**
Get a high-level view of marketplace health with key metrics, orders trends, 
and customer insights at a glance.

### 2. **Metrics Dashboard**
Deep-dive into detailed KPIs including monthly performance, product categories, 
delivery metrics, and customer quality indicators.

### 3. **Revenue RCA**
Analyze revenue performance using three-factor decomposition:
- **Users**: Active customer volume
- **Frequency**: Orders per user
- **AOV**: Average order value

Identify which factors drove revenue changes and their segment-level impacts.

---

## 🚀 Getting Started

### Prerequisites
- Python 3.8+
- All dependencies from `requirements.txt`
- Database with populated marketplace data

### Setup Steps

1. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Generate and load data**:
   ```bash
   python run_pipeline.py
   ```

3. **Launch the dashboard**:
   ```bash
   streamlit run dashboard/app.py
   ```

---

## 📁 Project Structure

```
├── dashboard/
│   ├── app.py                    # Main Streamlit app
│   └── pages/
│       ├── 01_overview.py        # Overview dashboard
│       ├── 02_metrics.py         # Detailed metrics
│       └── 03_rca.py             # Revenue RCA analysis
├── notebooks/
│   ├── 01_eda_marketplace_overview.ipynb
│   ├── 02_revenue_rca.ipynb
│   └── 03_cohort_retention.ipynb
├── sql/
│   ├── 00_schema_setup.sql
│   ├── 01_data_quality.sql
│   ├── 02_marketplace_metrics.sql
│   ├── 03_revenue_rca.sql
│   ├── 04_customer_segmentation.sql
│   ├── 05_cohort_retention.sql
│   └── 06_geographic_analysis.sql
├── src/
│   ├── data_generator.py         # Generate synthetic data
│   ├── data_loading.py           # Load data into DB
│   └── db_connect.py             # Database connection
├── data/
│   ├── raw/                      # Raw data
│   └── processed/                # Processed CSV files
├── reports/
│   └── *.png                     # Generated visualizations
├── docs/
│   ├── data_dictionary.md
│   ├── data_limitations.md
│   ├── experiment_proposal.md
│   └── metric_definitions.md
├── run_pipeline.py               # Data pipeline orchestrator
└── requirements.txt              # Python dependencies
```

---

## 🔍 Key Features

### Interactive Dashboards
- Real-time KPI monitoring
- Dynamic filtering by date range
- Segment-level analysis (geography, category, customer cohort)

### Advanced Analytics
- Three-factor revenue decomposition
- Cohort retention analysis
- Lifetime value (LTV) tracking
- Geographic performance mapping

### Data Quality
- Comprehensive data validation
- Freshness monitoring
- Missing value tracking

---

## Dashboards Overview

### Overview Dashboard
**Best for**: Executive summary and quick insights
- Total orders, GMV, AOV
- Monthly trends
- Order status distribution
- Customer acquisition metrics

### Metrics Dashboard
**Best for**: Detailed KPI analysis
- Monthly KPI scorecard
- Product category performance
- Delivery performance metrics
- Review sentiment analysis
- Customer repeat behavior

### Revenue RCA Dashboard
**Best for**: Understanding revenue drivers
- Three-factor decomposition
- Period-over-period comparison
- Segment impact analysis (geography, category)
- Contribution breakdown

---

## 💡 Use Cases

### Scenario 1: Rush Hour Traffic Analysis
Use the overview dashboard to monitor order velocity and identify peak traffic times 
for resource allocation.

### Scenario 2: Category Performance Review
Navigate to the Metrics Dashboard to analyze which product categories drive the most 
revenue and volume.

### Scenario 3: Revenue Decline Investigation
Use the Revenue RCA dashboard to decompose a month-over-month decline into user, 
frequency, and AOV factors. Then drill down by geography and category to identify 
problem areas.

### Scenario 4: Long-term Retention Tracking
Run the cohort analysis notebook to track how customer quality improves over time 
and identify seasonal retention patterns.

---

## 🔗 Database Architecture

The system uses a star schema design optimized for analytics:

**Fact Tables** (granular transaction-level data):
- `fact_orders` — Order-level transactions
- `fact_order_items` — Line-item details
- `fact_order_payments` — Payment records
- `fact_order_reviews` — Customer reviews

**Dimension Tables** (attributes and hierarchies):
- `dim_customers` — Customer master
- `dim_products` — Product catalog
- `dim_sellers` — Merchant partners
- `dim_geography` — Geographic reference

---

## Sample Insights from This Dataset

1. **Market Size**: ~40,000 orders from ~30,000 unique customers across 15 Brazilian states
2. **Peak Month**: April 2018 with ~4,600 delivered orders
3. **Contraction**: ~10% GMV decline in May 2018, primarily driven by AOV reduction (~4%)
4. **Top Region**: São Paulo (SP) accounts for ~42% of orders
5. **On-Time Delivery**: ~88% of orders delivered by promised date

---

## Configuration

### Environment Variables (Optional)
Create a `.env` file in the project root:

```
MYSQL_USER=root
MYSQL_PASSWORD=your_password
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_DB=marketplace_db
```

If MySQL is unavailable, the system automatically falls back to SQLite.

---

## 🐛 Troubleshooting

### Database Connection Issues
- Verify MySQL is running (if using MySQL)
- Check environment variables
- System will automatically fall back to SQLite

### Missing Data Tables
- Run `python run_pipeline.py` to generate and load data
- Check that CSV files exist in `data/processed/`

### Missing Visualizations
- Ensure all dependencies are installed: `pip install -r requirements.txt`
- Restart the Streamlit app

---

## 📚 Analysis Notebooks

Launch Jupyter notebooks for exploratory analysis:

```bash
jupyter notebook notebooks/
```

**Available Notebooks**:
1. **01_eda_marketplace_overview.ipynb** — Comprehensive market overview
2. **02_revenue_rca.ipynb** — Detailed revenue decomposition
3. **03_cohort_retention.ipynb** — Customer cohort analysis

---

## Next Steps

- **Monitor**: Use dashboards for ongoing performance tracking
- **Analyze**: Explore notebooks for deeper insights
- **Act**: Use findings to drive business decisions
- **Extend**: Adapt queries in `sql/` for custom analyses

---

## 📞 Support

For issues or questions:
1. Check the `docs/` folder for detailed documentation
2. Review SQL files in `sql/` for metric definitions
3. Consult notebook comments for analysis methodology

---

**Last Updated**: """ + __import__("datetime").datetime.now().strftime("%Y-%m-%d %H:%M"))
st.markdown("---")
