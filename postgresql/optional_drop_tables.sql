-- =====================================================
-- OPTIONAL: DROP POSTGRESQL TABLES (everything is commented out)
-- Nothing here is required. Remove the "--" only for tables you really want to delete.
-- DROP deletes the table AND its data permanently.
-- Order matters: drop child tables before their parents,
-- or use CASCADE (which also deletes dependent constraints/objects).
-- =====================================================

-- Child tables first (nothing depends on these):
-- DROP TABLE IF EXISTS reviews;
-- DROP TABLE IF EXISTS deliveries;
-- DROP TABLE IF EXISTS payments;
-- DROP TABLE IF EXISTS order_items;

-- Then:
-- DROP TABLE IF EXISTS orders;            -- needs reviews, deliveries, payments, order_items gone first
-- DROP TABLE IF EXISTS menu_items;        -- needs order_items gone first
-- DROP TABLE IF EXISTS menu_categories;   -- needs menu_items gone first

-- Parents last:
-- DROP TABLE IF EXISTS delivery_agents;   -- needs orders and deliveries gone first
-- DROP TABLE IF EXISTS customers;         -- needs orders and reviews gone first
-- DROP TABLE IF EXISTS restaurants;       -- needs categories, items, orders, reviews gone first

-- Shortcut for a single table together with everything that depends on it:
-- DROP TABLE IF EXISTS deliveries CASCADE;

-- Objects created by all_queries.sql (only if you want to remove them):
-- DROP VIEW IF EXISTS v_order_summary;
-- DROP TRIGGER IF EXISTS trg_order_items_available ON order_items;
-- DROP FUNCTION IF EXISTS trg_check_item_available();
-- DROP FUNCTION IF EXISTS fn_order_total(BIGINT);
