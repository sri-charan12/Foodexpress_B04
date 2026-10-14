# Food Express: complete project guide

## File structure
```
food_express_project/
├── README.md                          <- this guide
├── 1_postgresql/                      <- run in pgAdmin (database: food_express)
│   ├── 01_create_tables.sql           creates the 9 tables
│   ├── 02_insert_data.sql             inserts the 100-record data
│   ├── 03_all_queries.sql             every query, view, function, trigger, index, EXPLAIN, pg_stat_statements
│   ├── drop_reviews_postgres.sql      drops the reviews table after it is moved to MongoDB
│   └── optional_drop_tables.sql       all drops commented out, for tables you decide to remove
├── 2_mongodb/                         <- run in MongoDB Compass (mongosh panel)
│   ├── stage3_mongo.js                creates menu_details, order_tracking, agent_locations
│   └── stage3b_reviews_mongo.js       creates reviews (moved from PostgreSQL)
├── 3_app/                             <- run in a terminal (Python)
│   ├── .env.example                   copy to ".env" and fill in passwords
│   ├── requirements.txt               Python packages
│   ├── db.py                          connects to both databases + status checks
│   ├── simulate_gps.py                fake delivery-agent GPS tracker writing into MongoDB
│   └── app.py                         Streamlit frontend
└── presentation/
    └── Food_Express_Pro_v2.pptx       slides (still shows reviews in PostgreSQL, not yet updated)
```

## Which database holds what
| PostgreSQL (9 tables) | MongoDB (4 collections) |
|---|---|
| restaurants, customers, delivery_agents | menu_details |
| menu_categories, menu_items | order_tracking |
| orders, order_items | agent_locations |
| payments, deliveries | reviews |

Ids link the two sides: item_id, order_id, agent_id, restaurant_id, customer_id.

## Run order: what to paste and where

| Step | File | Where to open and run | Expected result |
|---|---|---|---|
| 1 | 1_postgresql/01_create_tables.sql | pgAdmin: right-click food_express > Query Tool > open file > F5. **Skip if your tables already exist.** It drops and recreates tables. | 9 tables (10 if reviews still exists) |
| 2 | 1_postgresql/02_insert_data.sql | Same Query Tool, open file, F5 (whole file). **Already done.** It empties the tables first. | "Query returned successfully" |
| 3 | 1_postgresql/03_all_queries.sql | Query Tool. **Select ONE query, press F5.** Never run the whole file. | Result in Data Output |
| 4 | 2_mongodb/stage3_mongo.js | First, in pgAdmin run `SELECT delivery_agent_id FROM orders WHERE order_id = 3;` and set `AGENT_ID` at the top of the file. Then Compass: connect to mongodb://localhost:27017 > mongosh panel at the bottom > paste whole file > Enter. | counts 10, 10, 15 |
| 5 | 2_mongodb/stage3b_reviews_mongo.js | Compass mongosh panel, paste whole file, Enter. | `reviews: 30` |
| 6 | 1_postgresql/drop_reviews_postgres.sql | pgAdmin Query Tool, F5. **Only after step 5 shows 30.** | 9 tables listed |
| 7 | 3_app/ | Terminal in the 3_app folder: `pip install -r requirements.txt`, copy `.env.example` to `.env` and put your PostgreSQL password in it | packages installed |
| 8 | 3_app/simulate_gps.py | Terminal 1: `python simulate_gps.py` (keeps writing GPS points for order 3) | "point 1/40 ..." lines |
| 9 | 3_app/app.py | Terminal 2: `streamlit run app.py`, then open http://localhost:8501 | App with green Connected badges |

## Demo: connected / not connected
Stop the MongoDB service (Windows Services > MongoDB > Stop), click "Refresh connection status" in the app: MongoDB turns red and pages show a warning. Start the service again and refresh: green.

## Notes
- Run each file once, in the order above. Steps 4 and 5 reset their own collections if repeated.
- 03_all_queries.sql: run the CREATE INDEX block only once. Queries 1.7 and 2.6 (ratings) moved to MongoDB; the aggregations are in stage3b_reviews_mongo.js.
- pg_stat_statements (end of 03_all_queries.sql) needs a postgresql.conf edit and a service restart first.
- Not yet verified by me: none of the SQL, JS or Python has been run against real databases except your own run of the insert file.
- Not yet updated: the PowerPoint (still shows reviews in PostgreSQL) and the app has no reviews page yet.
