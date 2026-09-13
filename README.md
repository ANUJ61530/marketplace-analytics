# Food Delivery Marketplace Analytics Platform

A comprehensive analytics platform for monitoring and analyzing food delivery marketplace performance. Includes data generation, SQL analytics, Jupyter notebooks, and interactive Streamlit dashboards.

## 🎯 Project Overview

This project demonstrates end-to-end analytics for a multi-vendor food delivery marketplace (Olist-inspired dataset). It features:

- **40,000+ synthetic orders** from 30,000+ unique customers
- **Realistic marketplace dynamics** with documented revenue drivers
- **Star schema data warehouse** optimized for business intelligence
- **Interactive dashboards** for real-time monitoring
- **Advanced analytics** including revenue decomposition and cohort retention

### Key Scenario: Revenue Decline Analysis

The dataset includes a realistic ~10% month-over-month revenue decline in May 2018, designed for root cause analysis. Using three-factor decomposition (**GMV = Users × Frequency × AOV**), stakeholders can isolate exact drivers:
- **User Volume Effect**: Customer acquisition changes
- **Order Frequency Effect**: Repeat purchase patterns
- **AOV Effect**: Pricing and basket size

---

## 🚀 Quick Start

### 1. Install Dependencies
```bash
cd /Users/anujkothari/Desktop/resume_projecta
pip install -r requirements.txt
```

### 2. Generate & Load Data
```bash
python run_pipeline.py
```

This will:
- Generate 40,000 synthetic orders (takes ~30 seconds)
- Load data into SQLite (or MySQL if configured)
- Create analytical views
- Prepare data for analysis

### 3. Launch Dashboard
```bash
streamlit run dashboard/app.py
```

Then open: **http://localhost:8501**

### 4. Explore Notebooks (Optional)
```bash
jupyter notebook notebooks/
```

---

## 📊 Dashboards & Analytics

### Overview (01_overview.py)
**Executive summary dashboard** — Quick view of marketplace health

**Key Metrics:**
- Total orders, deliveries, GMV, AOV
- Monthly trends
- Order status distribution
- Customer acquisition

**Best For:** Executive briefings, daily health checks

---

### Metrics Dashboard (02_metrics.py)
**Deep-dive into performance details** — Comprehensive KPI analysis

**Includes:**
- Monthly KPI scorecard
- Category performance
- Delivery metrics (on-time %, days to deliver)
- Review sentiment analysis
- Customer repeat behavior

**Best For:** Operational analysis, category management

---

### Revenue RCA Dashboard (03_rca.py)
**Root cause analysis** — Three-factor revenue decomposition

**Analyzes:**
- User volume changes
- Order frequency trends
- AOV movements
- Segment impact (geography, category)

**Best For:** Finance, strategy, explaining revenue swings

---

## 📓 Jupyter Notebooks

### 01_eda_marketplace_overview.ipynb
Exploratory data analysis with visualizations:
- Order volume and GMV trends
- Geographic distribution
- Product category analysis
- Delivery performance
- Customer satisfaction (review scores)

**Output**: 5 PNG reports (saved to `reports/`)

---

### 02_revenue_rca.ipynb
Mathematical revenue decomposition analysis:
- Baseline vs. contraction period comparison
- Three-factor model with contribution breakdown
- Segment-level impact analysis
- Waterfall visualization
- Actionable recommendations

**Datasets Used**: April vs. May 2018 (documenteddownturn scenario)

---

### 03_cohort_retention.ipynb
Customer cohort and lifetime value analysis:
- Cohort retention matrices (% returning by month)
- Lifetime value (LTV) tracking
- Month-over-month growth
- Orders per customer trends
- Retention heatmaps

**Outputs**: Retention matrix, LTV trends, MoM growth

---

## 🗂️ Project Structure

```
resume_projecta/
├── dashboard/
│   ├── app.py                        # Main Streamlit entry point
│   └── pages/
│       ├── 01_overview.py            # Overview dashboard
│       ├── 02_metrics.py             # Metrics deep-dive
│       └── 03_rca.py                 # Revenue RCA
│
├── notebooks/
│   ├── 01_eda_marketplace_overview.ipynb    # EDA & visualizations
│   ├── 02_revenue_rca.ipynb                 # Revenue decomposition
│   └── 03_cohort_retention.ipynb            # Cohort analysis
│
├── sql/
│   ├── 00_schema_setup.sql           # Database DDL
│   ├── 01_data_quality.sql           # Validation queries
│   ├── 02_marketplace_metrics.sql    # KPI calculations
│   ├── 03_revenue_rca.sql            # Decomposition model
│   ├── 04_customer_segmentation.sql  # Customer analysis
│   ├── 05_cohort_retention.sql       # Cohort analytics
│   └── 06_geographic_analysis.sql    # Geographic drill-down
│
├── src/
│   ├── data_generator.py             # Synthetic data generation (~40K orders)
│   ├── data_loading.py               # CSV → Database loader
│   └── db_connect.py                 # Connection factory (MySQL/SQLite)
│
├── data/
│   ├── raw/                          # (Reserved for raw imports)
│   └── processed/                    # Generated CSVs
│       ├── dim_customers.csv
│       ├── dim_products.csv
│       ├── dim_sellers.csv
│       ├── fact_orders.csv
│       ├── fact_order_items.csv
│       ├── fact_order_payments.csv
│       ├── fact_order_reviews.csv
│       └── synthetic_funnel_events.csv
│
├── reports/
│   ├── 01_monthly_trends.png
│   ├── 02_geographic_analysis.png
│   ├── 03_category_analysis.png
│   ├── 04_review_analysis.png
│   ├── 05_delivery_performance.png
│   ├── 06_rca_decomposition_waterfall.png
│   ├── 07_cohort_retention_heatmap.png
│   └── 08_ltv_trends.png
│
├── docs/
│   ├── data_dictionary.md            # Schema & grain documentation
│   ├── data_limitations.md           # Known constraints
│   ├── experiment_proposal.md        # Example A/B test design
│   └── metric_definitions.md         # KPI formulas
│
├── run_pipeline.py                   # Data orchestration script
├── requirements.txt                  # Python dependencies
└── README.md                         # This file
```

---

## 🗄️ Database Architecture

**Star Schema Design** (Kimball Dimensional Modeling)

### Fact Tables (Transaction-Level Granularity)

| Table | Grain | Key Columns |
|-------|-------|------------|
| `fact_orders` | 1 row per order | order_id, customer_id, order_status, order_purchase_timestamp, order_gmv |
| `fact_order_items` | 1 row per item in order | order_id, order_item_id, product_id, seller_id, price, freight_value |
| `fact_order_payments` | 1 row per payment method per order | order_id, payment_sequential, payment_type, payment_value |
| `fact_order_reviews` | 1 row per review | review_id, order_id, review_score, review_creation_date |

### Dimension Tables (Attributes)

| Table | Grain | Key Columns |
|-------|-------|------------|
| `dim_customers` | 1 row per unique customer | customer_unique_id, customer_city, customer_state, cohort_month |
| `dim_products` | 1 row per product SKU | product_id, category_name_english, product_weight_g |
| `dim_sellers` | 1 row per merchant partner | seller_id, seller_zip_code_prefix, seller_state |
| `dim_geography` | 1 row per zip code | zip_code_prefix, city, state, latitude, longitude |

---

## 📈 Dataset Characteristics

### Volume
- **Orders**: 40,000
- **Unique Customers**: ~30,000 (78% repeat customer pool)
- **Products**: 4,000
- **Sellers**: 1,200
- **Funnel Events**: 15,000 clickstream logs

### Time Period
- **Range**: January 2017 — June 2018 (18 months)
- **Peak Month**: April 2018 (4,600 orders)
- **Contraction Scenario**: May 2018 (~10% GMV decline)

### Geographic Coverage
- **States**: 15 Brazilian states
- **Top Market**: São Paulo (42% of volume)
- **Regions**: Concentrated in Southeast (68%)

### Product Categories
- **15 categories** ranging from electronics to home décor
- **Price ranges**: BRL 15–210 baseline (with realistic variation)
- **Weight-based shipping**: Logistics cost simulation

---

## 🔍 Key Insights (Sample)

### Market Health
- **On-time Delivery**: 88% of delivered orders arrived by promised date
- **Repeat Purchase Rate**: 42% of customers make 2+ purchases
- **Review Score**: 4.1/5.0 average (highly positive)

### Revenue Performance
- **Delivered GMV**: BRL ~650K (April 2018)
- **AOV Trend**: Declining in May 2018 (~4% drop)
- **Customer Acquisition**: Slight increase (+2%), offset by AOV decline

### Cancellation & Quality
- **Cancellation Rate**: 1.8% overall
- **Late Delivery Impact**: ~41% more 1-star reviews for late orders

---

## ⚙️ Configuration

### Environment Variables (Optional)
Create `.env` file in project root to configure MySQL:

```env
MYSQL_USER=root
MYSQL_PASSWORD=your_secure_password
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_DB=marketplace_db
```

**Note**: If MySQL is unavailable, system automatically falls back to SQLite (`data/processed/marketplace.db`)

### Streamlit Config (Optional)
Customize dashboard by editing `~/.streamlit/config.toml` or creating `.streamlit/config.toml` in project root:

```toml
[theme]
primaryColor = "#2E86AB"
backgroundColor = "#FFFFFF"
secondaryBackgroundColor = "#F0F2F6"

[server]
maxUploadSize = 500
```

---

## 📊 Usage Scenarios

### Scenario 1: Executive Briefing
**Question**: "How did we perform last month?"
- Launch **Overview Dashboard**
- Check KPI cards (orders, GMV, AOV)
- Review monthly trends
- Share findings in 5 minutes

---

### Scenario 2: Revenue Decline Investigation
**Question**: "Why did May revenue drop 10%?"
- Navigate to **Revenue RCA Dashboard**
- Select April 2018 (T0) vs. May 2018 (T1)
- View three-factor decomposition
- Drill down by state and category to identify problem areas
- Present findings with supporting data

---

### Scenario 3: Category Performance Review
**Question**: "Which product categories need attention?"
- Open **Metrics Dashboard**
- Scroll to "Product Category Performance"
- Analyze items sold vs. GMV per category
- Top performers: Health & Beauty, Watches & Gifts
- Bottom performers: Telephony, Electronics

---

### Scenario 4: Customer Health Assessment
**Question**: "Are we acquiring and retaining customers?"
- Run **03_cohort_retention.ipynb**
- Review cohort retention heatmap
- Check LTV trends over time
- Newer cohorts show improving LTV (+12% Jan→Jun)

---

## 🧪 Testing & Validation

### Data Quality Checks
Run SQL validation:
```bash
# Connect to database (MySQL or SQLite)
# Execute sql/01_data_quality.sql
```

Checks include:
- Null value distribution
- Key referential integrity
- Grain validation (one row per entity)
- Completeness rates

### Portfolio Health
Verify data was generated successfully:
```bash
ls -lah data/processed/
# Should show 8 CSV files with sizes:
# - dim_customers.csv: ~1.5MB
# - fact_orders.csv: ~800KB
# - fact_order_items.csv: ~2.1MB
# (and 5 more)
```

### Pipeline Validation
After running `python run_pipeline.py`, verify:
```bash
# Check table counts
sqlite3 data/processed/marketplace.db
> SELECT 'fact_orders' as table_name, COUNT(*) as row_count FROM fact_orders;
> SELECT 'dim_customers' as table_name, COUNT(*) as row_count FROM dim_customers;
```

---

## 🔧 Customization

### Add New Analysis Metric

1. **Define in SQL** (`sql/02_marketplace_metrics.sql`):
   ```sql
   SELECT 
       DATE_FORMAT(...) AS month,
       YOUR_METRIC
   FROM fact_orders
   GROUP BY month;
   ```

2. **Add to Dashboard** (`dashboard/pages/02_metrics.py`):
   ```python
   new_metric = df.groupby('month')['your_column'].agg('sum')
   fig = px.line(x=new_metric.index, y=new_metric.values)
   st.plotly_chart(fig, use_container_width=True)
   ```

3. **Document** in `docs/metric_definitions.md`

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Database connection failed" | Run `python run_pipeline.py` to generate data |
| "ModuleNotFoundError: No module named 'streamlit'" | Run `pip install -r requirements.txt` |
| Charts not loading | Clear Streamlit cache: `streamlit cache clear` |
| Slow dashboard on large dataset | Filter date range in sidebar |
| SQLite database locked | Close other connections; SQLite has limited concurrency |

---

## 📚 Documentation

### Files to Review

1. **`docs/data_dictionary.md`** — Complete schema, grain validation, business rules
2. **`docs/metric_definitions.md`** — Formulas for all KPIs
3. **`docs/data_limitations.md`** — Known constraints and considerations
4. **`docs/experiment_proposal.md`** — Example A/B test design for platform

### SQL Reference

Each SQL file documents specific business logic:
- `00_schema_setup.sql` — DDL with indexes and constraints
- `02_marketplace_metrics.sql` — Monthly KPI calculations
- `03_revenue_rca.sql` — Detailed decomposition model
- `05_cohort_retention.sql` — Cohort survival analysis

---

## 🎓 Learning Resources

This project demonstrates:
- **Data Engineering**: Synthetic data generation with realistic trends
- **ETL Pipelines**: CSV ingestion, transformation, loading
- **Data Modeling**: Star schema design with grain validation
- **SQL Analytics**: Aggregations, window functions, cohort analysis
- **Business Intelligence**: Dashboard design, metric definition
- **Python**: Pandas, SQLAlchemy, Streamlit, Plotly
- **Root Cause Analysis**: Three-factor revenue decomposition

---

## 📄 License

This project is provided as-is for educational and demonstration purposes.

---

## 📞 Support & Questions

- **Data Issues**: Check `docs/data_limitations.md`
- **Dashboard Problems**: Review Streamlit logs: `streamlit run ... --logger.level=debug`
- **SQL Errors**: Review schema in `sql/00_schema_setup.sql`
- **General Questions**: See example narratives in `docs/experiment_proposal.md`

---

## 🚀 Next Steps

1. ✅ **Run the pipeline** → `python run_pipeline.py`
2. ✅ **Launch dashboard** → `streamlit run dashboard/app.py`
3. ✅ **Explore notebooks** → `jupyter notebook notebooks/`
4. 📊 **Perform custom analysis** → Write SQL in `sql/` files
5. 📈 **Add new metrics** → Create dashboard pages in `dashboard/pages/`

---

**Project Last Updated**: 2026-09-14  
**Python Version**: 3.8+  
**Data Generation Method**: Synthetic (deterministic, reproducible)  
**Database Support**: MySQL 8.0+, SQLite 3.0+
