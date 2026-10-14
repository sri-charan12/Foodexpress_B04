-- =====================================================
-- FILE 4: CONCURRENCY + DEADLOCK  (Food Express, PostgreSQL)
-- How to run: open TWO query tabs in pgAdmin (Session 1 and Session 2).
-- Run the steps in the order shown. Every demo ends with ROLLBACK, so data is unchanged.
-- pgAdmin tip: select the lines of one step, then press F5.
-- =====================================================


-- =====================================================
-- PART 0: SETTINGS
-- =====================================================
SHOW deadlock_timeout;                      -- default 1s = how long Postgres waits before checking for a deadlock
ALTER SYSTEM SET deadlock_timeout = '500ms';
SELECT pg_reload_conf();                    -- applies it (no restart needed)
SHOW lock_timeout;                          -- 0 = wait forever


-- =====================================================
-- PART 1: DEADLOCK DEMO (two sessions lock the same 2 rows in opposite order)
-- =====================================================

-- STEP 1 (Session 1)
BEGIN;
UPDATE orders SET order_status = 'PREPARING' WHERE order_id = 1;   -- locks order 1

-- STEP 2 (Session 2)
BEGIN;
UPDATE orders SET order_status = 'PREPARING' WHERE order_id = 2;   -- locks order 2

-- STEP 3 (Session 1)  -> waits for Session 2
UPDATE orders SET order_status = 'PREPARING' WHERE order_id = 2;

-- STEP 4 (Session 2)  -> circular wait
UPDATE orders SET order_status = 'PREPARING' WHERE order_id = 1;
-- Result: after ~500ms Postgres kills ONE session:
--   ERROR: deadlock detected   (SQLSTATE 40P01)
-- The other session continues.

-- STEP 5 (both sessions)
ROLLBACK;


-- =====================================================
-- PART 1b: DEADLOCK FIX = always lock rows in the same order
-- =====================================================
-- Both sessions run the SAME pattern. The second one just waits, no deadlock.

-- Session 1
BEGIN;
SELECT order_id FROM orders WHERE order_id IN (1, 2) ORDER BY order_id FOR UPDATE;
UPDATE orders SET order_status = 'PREPARING' WHERE order_id IN (1, 2);

-- Session 2 (run while Session 1 is still open: it waits, then continues after Session 1 commits)
BEGIN;
SELECT order_id FROM orders WHERE order_id IN (1, 2) ORDER BY order_id FOR UPDATE;
UPDATE orders SET order_status = 'PREPARING' WHERE order_id IN (1, 2);

-- Session 1
COMMIT;      -- then Session 2 gets its locks
-- Session 2
ROLLBACK;


-- =====================================================
-- PART 2: RACE CONDITION - two orders grab the same delivery agent
-- =====================================================
-- Reset test data first (run once)
UPDATE delivery_agents SET is_available = TRUE;
UPDATE orders SET delivery_agent_id = NULL WHERE order_id IN (5, 6);

-- ---- 2a. THE PROBLEM (no locking) ----
-- Session 1
BEGIN;
SELECT agent_id FROM delivery_agents WHERE is_available ORDER BY agent_id LIMIT 1;   -- e.g. agent 1

-- Session 2
BEGIN;
SELECT agent_id FROM delivery_agents WHERE is_available ORDER BY agent_id LIMIT 1;   -- ALSO agent 1  (problem!)

-- Both then do: UPDATE orders SET delivery_agent_id = 1 ... -> same agent assigned twice.
-- Both sessions
ROLLBACK;

-- ---- 2b. THE FIX: FOR UPDATE SKIP LOCKED ----
-- Session 1
BEGIN;
SELECT agent_id FROM delivery_agents
WHERE is_available ORDER BY agent_id LIMIT 1
FOR UPDATE SKIP LOCKED;                                   -- gets agent 1 and locks it

-- Session 2 (while Session 1 is open)
BEGIN;
SELECT agent_id FROM delivery_agents
WHERE is_available ORDER BY agent_id LIMIT 1
FOR UPDATE SKIP LOCKED;                                   -- skips agent 1, gets agent 2

-- Both sessions
ROLLBACK;

-- ---- 2c. Production version: assign an agent in ONE atomic statement ----
WITH pick AS (
    SELECT agent_id FROM delivery_agents
    WHERE is_available
    ORDER BY agent_id
    LIMIT 1
    FOR UPDATE SKIP LOCKED
), taken AS (
    UPDATE delivery_agents a SET is_available = FALSE
    FROM pick WHERE a.agent_id = pick.agent_id
    RETURNING a.agent_id
)
UPDATE orders o SET delivery_agent_id = taken.agent_id
FROM taken
WHERE o.order_id = 5
RETURNING o.order_id, o.delivery_agent_id;
-- Run it from 2 sessions for order 5 and order 6: each gets a different agent.

-- cleanup
UPDATE delivery_agents SET is_available = TRUE;
UPDATE orders SET delivery_agent_id = NULL WHERE order_id IN (5, 6);


-- =====================================================
-- PART 3: LOST UPDATE on order status (cancel vs. advance)
-- =====================================================
-- Without a lock, "check status then update" can overwrite another session's change.
-- Fix: lock the row first, then check.

-- Session 1 (customer cancels)
BEGIN;
SELECT order_status FROM orders WHERE order_id = 1 FOR UPDATE;
UPDATE orders SET order_status = 'CANCELLED'
WHERE order_id = 1 AND order_status IN ('PLACED', 'PREPARING');

-- Session 2 (restaurant marks it out for delivery at the same moment)
BEGIN;
SELECT order_status FROM orders WHERE order_id = 1 FOR UPDATE;   -- WAITS for Session 1
-- After Session 1 COMMITs, Session 2 sees 'CANCELLED' and the app must NOT continue.

-- Session 1
COMMIT;
-- Session 2
ROLLBACK;

-- Reset
UPDATE orders SET order_status = 'PLACED' WHERE order_id = 1;   -- use the original status of your row


-- =====================================================
-- PART 4: ISOLATION LEVELS
-- =====================================================

-- ---- 4a. READ COMMITTED (default): non-repeatable read ----
-- Session 1
BEGIN;
SELECT SUM(amount) FROM payments WHERE payment_status = 'SUCCESS';   -- value A

-- Session 2
BEGIN;
UPDATE payments SET payment_status = 'REFUNDED' WHERE order_id = 1;
COMMIT;

-- Session 1
SELECT SUM(amount) FROM payments WHERE payment_status = 'SUCCESS';   -- value B (different!)
ROLLBACK;

-- Reset
UPDATE payments SET payment_status = 'SUCCESS' WHERE order_id = 1;   -- use the original status of your row

-- ---- 4b. REPEATABLE READ: same snapshot for the whole transaction ----
-- Session 1
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT SUM(amount) FROM payments WHERE payment_status = 'SUCCESS';   -- value A

-- Session 2
UPDATE payments SET payment_status = 'REFUNDED' WHERE order_id = 1;  -- autocommit

-- Session 1
SELECT SUM(amount) FROM payments WHERE payment_status = 'SUCCESS';   -- still value A
UPDATE payments SET payment_status = 'FAILED' WHERE order_id = 1;
-- ERROR: could not serialize access due to concurrent update  (SQLSTATE 40001)
ROLLBACK;                                                            -- app should RETRY the transaction

-- Reset
UPDATE payments SET payment_status = 'SUCCESS' WHERE order_id = 1;   -- use the original status of your row


-- =====================================================
-- PART 5: OPTIMISTIC LOCKING (no long locks; detect conflicts by version)
-- =====================================================
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;

-- Two admins read price at version 1. Both run this; only the first succeeds.
UPDATE menu_items
SET price = 250, version = version + 1
WHERE item_id = 1 AND version = 1;
-- "UPDATE 1" = success.  "UPDATE 0" = someone else changed it first -> reload and retry.


-- =====================================================
-- PART 6: OTHER LOCK OPTIONS
-- =====================================================
-- Fail fast instead of waiting forever
BEGIN;
SET LOCAL lock_timeout = '2s';
SELECT * FROM orders WHERE order_id = 1 FOR UPDATE NOWAIT;   -- error at once if row is locked
ROLLBACK;

-- Application-level lock (e.g. one nightly job at a time)
SELECT pg_try_advisory_lock(42);      -- TRUE = got it, FALSE = another session has it
SELECT pg_advisory_unlock(42);


-- =====================================================
-- PART 7: MONITORING (run in a THIRD tab while sessions are blocked)
-- =====================================================
-- Who is blocked and by whom
SELECT blocked.pid  AS blocked_pid,
       LEFT(blocked.query, 60)  AS blocked_query,
       blocking.pid AS blocking_pid,
       LEFT(blocking.query, 60) AS blocking_query
FROM pg_stat_activity blocked
JOIN LATERAL unnest(pg_blocking_pids(blocked.pid)) AS b(pid) ON TRUE
JOIN pg_stat_activity blocking ON blocking.pid = b.pid;

-- All current locks
SELECT l.pid, l.locktype, l.mode, l.granted, c.relname
FROM pg_locks l
LEFT JOIN pg_class c ON c.oid = l.relation
WHERE l.pid <> pg_backend_pid()
ORDER BY l.pid;

-- Deadlocks recorded for this database
SELECT datname, deadlocks FROM pg_stat_database WHERE datname = 'food_express';

-- Kill a stuck session if needed
-- SELECT pg_terminate_backend(<pid>);
