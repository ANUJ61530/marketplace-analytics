# Delivery Performance, Reviews and Retention (Olist marketplace)

An analysis of real marketplace orders: how deliveries are going, whether late deliveries hurt reviews, and how many customers come back. Built with SQL (SQLite), a Jupyter notebook, and a one-page Streamlit dashboard.

## Data
[Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce): about 99,000 real, anonymised orders from a Brazilian marketplace (Sep 2016 to Oct 2018). Licence CC BY-NC-SA 4.0.

This is an e-commerce marketplace, not a food delivery company. It is used because it has what a delivery platform tracks: order timestamps, promised delivery dates, actual delivery dates and customer reviews.

The six CSVs used are included in `data/raw/` (about 65MB), so the project runs without any download. They are an unmodified copy of the public dataset, shared under the same licence (CC BY-NC-SA 4.0) with credit to Olist. The original is on Kaggle if you want to check it:
`olist_customers_dataset.csv`, `olist_orders_dataset.csv`, `olist_order_items_dataset.csv`, `olist_order_reviews_dataset.csv`, `olist_products_dataset.csv`, `product_category_name_translation.csv`

## Run it
```bash
pip install -r requirements.txt
python build_db.py                      # loads CSVs into olist.db
jupyter notebook notebooks/delivery_analysis.ipynb
streamlit run dashboard/app.py
```

## Layout
```
build_db.py                 loads the CSVs into SQLite and builds order_facts
sql/01_order_facts.sql      one row per order (joins done once, at the right grain)
sql/02_analysis.sql         9 named queries, one per business question
utils.py                    runs a named query from the SQL file
notebooks/                  queries + charts + written takeaways
dashboard/app.py            KPIs and charts with a state filter
```

## Questions and answers
| # | Question | Answer |
|---|---|---|
| 1 | Order and GMV trend | Orders grew about 9x from Jan 2017 to Jan 2018, then flattened. Basket size stayed flat (147 to 174 BRL). |
| 2 | Delivery time and late rate | Late rate is spiky (1.4% to 21.4% by month). Average delivery time fell from 15.4 days (Dec 2017) to 7.7 days (Aug 2018). |
| 3 | Worst states | Highest late rates: MA 19.7%, CE 15.3%, BA 14.0%, RJ 13.5%. SP is the biggest market and one of the fastest. |
| 4 | Late vs reviews | On time: 4.28 stars. 1 to 3 days late: 3.75. 8+ days late: 1.72. |
| 5 | Repeat customers | 3.04% of customers ordered more than once. |
| 6 | Cohort return rate | 1.6% to 3.9% return within 90 days in every cohort. |
| 7 | Categories | Largest category is 9.3% of revenue; top 10 are 62.4%. |
| 8 | Sellers | Top 10% of sellers earn 67.6% of revenue. |
| 9 | Late first order vs return | 2.08% vs 2.32%, not statistically significant (z = 1.24). |

## SQL techniques used
- Collapse items and reviews to one row per order before joining, to avoid double counting
- CTEs, `LAG` (month-on-month growth), `ROW_NUMBER` (first and second order per customer), `NTILE` (seller deciles), running totals with `SUM() OVER`
- A two-proportion z-test in Python to check whether a difference is real

## Limitations
- One marketplace in one country, 2016 to 2018. Not a food delivery business.
- The review analysis is correlational: late orders may also have other problems.
- No acquisition cost, no promotions, no data on repeat orders made elsewhere.
- Months before Jan 2017 and after Aug 2018 are excluded because they have very few orders.
