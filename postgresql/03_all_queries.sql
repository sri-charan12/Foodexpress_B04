-- 1.1 Menu items with their category
SELECT m.item_name, c.category_name, m.price
FROM menu_items m
JOIN menu_categories c ON m.category_id = c.category_id
LIMIT 20;


-- 1.2 Full order detail with line amount
SELECT o.order_id, cu.customer_name, r.restaurant_name, mi.item_name,
       oi.quantity, oi.unit_price, (oi.quantity * oi.unit_price) AS line_amount
FROM orders o
JOIN customers cu   ON o.customer_id = cu.customer_id
JOIN restaurants r  ON o.restaurant_id = r.restaurant_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN menu_items mi  ON oi.item_id = mi.item_id
ORDER BY o.order_id
LIMIT 20;

-- 1.3 Order with its payment status
SELECT o.order_id, cu.customer_name, p.amount, p.payment_method, p.payment_status
FROM orders o
JOIN customers cu ON o.customer_id = cu.customer_id
JOIN payments p   ON o.order_id = p.order_id
LIMIT 20;

-- 1.4 Delivery tracking: which agent delivered which order
SELECT o.order_id, cu.customer_name, da.agent_name,
       d.delivery_status, d.pickup_time, d.delivery_time
FROM orders o
JOIN customers cu       ON o.customer_id = cu.customer_id
JOIN deliveries d       ON o.order_id = d.order_id
JOIN delivery_agents da ON d.agent_id = da.agent_id
LIMIT 20;

-- 1.5 LEFT JOIN: every restaurant with its order count (0 if none)
SELECT r.restaurant_name, COUNT(o.order_id) AS total_orders
FROM restaurants r
LEFT JOIN orders o ON r.restaurant_id = o.restaurant_id
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_orders DESC
LIMIT 20;

-- 1.6 Revenue per restaurant
SELECT r.restaurant_name, SUM(oi.quantity * oi.unit_price) AS total_revenue
FROM restaurants r
JOIN orders o       ON r.restaurant_id = o.restaurant_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY total_revenue DESC
LIMIT 20;

-- 1.7 Average rating per restaurant
--     MOVED TO MONGODB (reviews collection). Use stage3b_reviews_mongo.js:
--     db.reviews.aggregate([{ $group: { _id: "$restaurant_id", avg_rating: { $avg: "$rating" } } }, { $sort: { avg_rating: -1 } }])


-- =====================================================
-- PART 2: ANALYSIS QUERIES
-- =====================================================

-- 2.1 Orders per status
SELECT order_status, COUNT(*) AS total
FROM orders
GROUP BY order_status
ORDER BY total DESC;

-- 2.2 Top 10 customers by spend (successful payments)
SELECT cu.customer_name, SUM(p.amount) AS total_spent
FROM customers cu
JOIN orders o   ON o.customer_id = cu.customer_id
JOIN payments p ON p.order_id = o.order_id
WHERE p.payment_status = 'SUCCESS'
GROUP BY cu.customer_id, cu.customer_name
ORDER BY total_spent DESC
LIMIT 10;

-- 2.3 Best-selling items
SELECT mi.item_name, r.restaurant_name, SUM(oi.quantity) AS units_sold
FROM order_items oi
JOIN menu_items mi ON mi.item_id = oi.item_id
JOIN restaurants r ON r.restaurant_id = mi.restaurant_id
GROUP BY mi.item_id, mi.item_name, r.restaurant_name
ORDER BY units_sold DESC
LIMIT 10;

-- 2.4 Delivery time per delivered order (minutes)
SELECT da.agent_name, d.order_id,
       EXTRACT(EPOCH FROM (d.delivery_time - d.pickup_time)) / 60 AS minutes
FROM deliveries d
JOIN delivery_agents da ON da.agent_id = d.agent_id
WHERE d.delivery_status = 'DELIVERED'
LIMIT 10;

-- 2.5 Revenue by cuisine (delivered orders)
SELECT r.cuisine_type, SUM(oi.quantity * oi.unit_price) AS revenue
FROM restaurants r
JOIN orders o       ON o.restaurant_id = r.restaurant_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'DELIVERED'
GROUP BY r.cuisine_type
ORDER BY revenue DESC;

-- 2.6 CTE: restaurants rated above the overall average
--     MOVED TO MONGODB (reviews collection), see the commented examples in stage3b_reviews_mongo.js


-- 2.7 Window function: rank restaurants by revenue within each city
SELECT city, restaurant_name, revenue,
       RANK() OVER (PARTITION BY city ORDER BY revenue DESC) AS city_rank
FROM (
    SELECT r.city, r.restaurant_name, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM restaurants r
    JOIN orders o       ON o.restaurant_id = r.restaurant_id
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY r.restaurant_id, r.city, r.restaurant_name
) x
ORDER BY city, city_rank;

-- 2.8 Restaurants with no orders
SELECT r.restaurant_name
FROM restaurants r
LEFT JOIN orders o ON r.restaurant_id = o.restaurant_id
WHERE o.order_id IS NULL;


-- =====================================================
-- PART 3: VIEW, TRANSACTION, FUNCTION, TRIGGER
-- =====================================================

-- 3.1 View: order summary
CREATE OR REPLACE VIEW v_order_summary AS
SELECT o.order_id, o.order_status, cu.customer_name, r.restaurant_name,
       SUM(oi.quantity * oi.unit_price) AS order_total
FROM orders o
JOIN customers cu   ON cu.customer_id = o.customer_id
JOIN restaurants r  ON r.restaurant_id = o.restaurant_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.order_status, cu.customer_name, r.restaurant_name;

SELECT * FROM v_order_summary ORDER BY order_id LIMIT 10;

-- 3.2 Transaction: place an order + its payment atomically (select ALL lines from BEGIN to COMMIT, then F5)
--     use ROLLBACK; instead of COMMIT; to undo
BEGIN;
    INSERT INTO orders (customer_id, restaurant_id) VALUES (1, 1);
    INSERT INTO order_items (order_id, item_id, quantity, unit_price)
    SELECT currval(pg_get_serial_sequence('orders','order_id')), item_id, 1, price
    FROM menu_items WHERE restaurant_id = 1;
    INSERT INTO payments (order_id, amount, payment_method, payment_status)
    SELECT currval(pg_get_serial_sequence('orders','order_id')), SUM(quantity * unit_price), 'UPI', 'PENDING'
    FROM order_items
    WHERE order_id = currval(pg_get_serial_sequence('orders','order_id'));
COMMIT;

-- 3.3 Function: total of an order
CREATE OR REPLACE FUNCTION fn_order_total(p_order_id BIGINT)
RETURNS NUMERIC AS $$
    SELECT COALESCE(SUM(quantity * unit_price), 0)
    FROM order_items
    WHERE order_id = p_order_id;
$$ LANGUAGE sql STABLE;

SELECT fn_order_total(1);

-- 3.4 Trigger: block unavailable items (select the whole function + trigger, then F5)
CREATE OR REPLACE FUNCTION trg_check_item_available()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT (SELECT is_available FROM menu_items WHERE item_id = NEW.item_id) THEN
        RAISE EXCEPTION 'Item % is not available', NEW.item_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_items_available ON order_items;
CREATE TRIGGER trg_order_items_available
BEFORE INSERT ON order_items
FOR EACH ROW EXECUTE FUNCTION trg_check_item_available();



-- 4.1 BEFORE indexes (look for "Seq Scan" and "Execution Time")
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE customer_id = 50;

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders
WHERE order_status = 'DELIVERED' AND order_date >= CURRENT_TIMESTAMP - INTERVAL '90 days';

EXPLAIN (ANALYZE, BUFFERS)
SELECT r.restaurant_name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM restaurants r
JOIN orders o       ON o.restaurant_id = r.restaurant_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY revenue DESC;

-- 4.2 Create indexes (run once)
CREATE INDEX IF NOT EXISTS idx_orders_customer    ON orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_restaurant  ON orders (restaurant_id);
CREATE INDEX IF NOT EXISTS idx_orders_status_date ON orders (order_status, order_date);
CREATE INDEX IF NOT EXISTS idx_orders_agent       ON orders (delivery_agent_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_agent   ON deliveries (agent_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_cat     ON menu_items (category_id);
ANALYZE;

-- 4.3 AFTER indexes (tiny tables may still show Seq Scan, which is normal)
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE customer_id = 50;

-- 4.4 Force index use to SEE it (select all 5 lines, then F5; RESET at the end is important)
SET enable_seqscan = off;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE customer_id = 50;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders
WHERE order_status = 'DELIVERED' AND order_date >= CURRENT_TIMESTAMP - INTERVAL '90 days';
RESET enable_seqscan;

-- 4.5 Index usage and sizes
SELECT relname AS table_name, indexrelname AS index_name, idx_scan AS times_used
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;



-- needs pg_stat_statements in postgresql.conf (shared_preload_libraries) + server restart
SHOW shared_preload_libraries;          -- must contain pg_stat_statements

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

SELECT pg_stat_statements_reset();      -- clean stats

-- run a few queries so there is something to record
SELECT * FROM orders WHERE customer_id = 50;
SELECT COUNT(*) FROM order_items;

-- slowest queries by total time
SELECT ROUND(total_exec_time::NUMERIC, 3) AS total_ms, calls,
       ROUND(mean_exec_time::NUMERIC, 3) AS mean_ms, rows, LEFT(query, 80) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- most called queries
SELECT calls, LEFT(query, 80) AS query
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 10;



-- =====================================================
-- PART 5: TRANSACTIONS, CONCURRENCY AND DEADLOCK ON PAYMENTS
-- Use TWO pgAdmin Query Tool tabs (Session 1 / Session 2). Select the lines of a step, then F5.
-- Check the Messages tab for UPDATE 1 / UPDATE 0 / ERROR.
-- =====================================================

-- 5.0 Setting (run each line ALONE, ALTER SYSTEM cannot run inside a multi-statement run)
SHOW deadlock_timeout;
ALTER SYSTEM SET deadlock_timeout = '500ms';
SELECT pg_reload_conf();

-- 5.0b Reset test data (order 7)
UPDATE payments SET payment_status = 'PENDING' WHERE order_id = 7;
UPDATE orders   SET order_status   = 'PLACED'  WHERE order_id = 7;

-- 5.1 TRANSACTION: payment success + order status change together (select all lines, F5)
BEGIN;
SELECT order_status FROM orders WHERE order_id = 7 FOR UPDATE;       -- lock the order first
UPDATE payments SET payment_status = 'SUCCESS', payment_date = CURRENT_TIMESTAMP
WHERE order_id = 7 AND payment_status = 'PENDING';                   -- UPDATE 0 if already paid
UPDATE orders SET order_status = 'PREPARING'
WHERE order_id = 7 AND order_status = 'PLACED';
COMMIT;                                                              -- or ROLLBACK; to undo

SELECT o.order_id, o.order_status, p.payment_status
FROM orders o JOIN payments p ON p.order_id = o.order_id
WHERE o.order_id = 7;                                                -- expect PREPARING / SUCCESS

-- 5.2 CONCURRENCY: same payment from two sessions (duplicate click / gateway callback)
-- Session 1: run 5.1 up to the two UPDATEs, do NOT commit.
-- Session 2: run the same lines. The SELECT ... FOR UPDATE waits (spinner).
-- Session 1: COMMIT;   -> Session 2 wakes up and shows UPDATE 0 (paid only once).
-- Session 2: ROLLBACK;

-- 5.3 DEADLOCK: opposite lock order on payments and orders (reset 5.0b first)
-- Session 1
BEGIN;
UPDATE payments SET payment_status = 'SUCCESS' WHERE order_id = 7;
-- Session 2
BEGIN;
UPDATE orders SET order_status = 'PREPARING' WHERE order_id = 7;
-- Session 1 (waits)
UPDATE orders SET order_status = 'PREPARING' WHERE order_id = 7;
-- Session 2  -> ERROR: deadlock detected (SQLSTATE 40P01), one session is cancelled
UPDATE payments SET payment_status = 'SUCCESS' WHERE order_id = 7;
-- Both sessions
ROLLBACK;
-- FIX: always lock orders first, then payments (as in 5.1).

-- 5.4 Monitoring (run in a THIRD tab while sessions are blocked)
SELECT blocked.pid AS blocked_pid, LEFT(blocked.query, 60) AS blocked_query,
       blocking.pid AS blocking_pid, LEFT(blocking.query, 60) AS blocking_query
FROM pg_stat_activity blocked
JOIN LATERAL unnest(pg_blocking_pids(blocked.pid)) AS b(pid) ON TRUE
JOIN pg_stat_activity blocking ON blocking.pid = b.pid;

SELECT datname, deadlocks FROM pg_stat_database WHERE datname = 'food_express';

-- 5.5 Agent assignment with SKIP LOCKED (two orders must never get the same agent)
BEGIN;
WITH pick AS (
    SELECT agent_id FROM delivery_agents
    WHERE is_available ORDER BY agent_id LIMIT 1
    FOR UPDATE SKIP LOCKED
), taken AS (
    UPDATE delivery_agents a SET is_available = FALSE
    FROM pick WHERE a.agent_id = pick.agent_id
    RETURNING a.agent_id
)
UPDATE orders o SET delivery_agent_id = taken.agent_id
FROM taken WHERE o.order_id = 5
RETURNING o.order_id, o.delivery_agent_id;
COMMIT;