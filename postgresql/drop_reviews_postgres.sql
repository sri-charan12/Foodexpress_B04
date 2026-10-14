-- =====================================================
-- RUN THIS IN pgAdmin (food_express) ONLY AFTER stage3b_reviews_mongo.js
-- has run and printed "reviews: 30" in MongoDB.
-- DROP deletes the table and its data permanently.
-- Its index idx_reviews_restaurant is removed automatically with it.
-- =====================================================

DROP TABLE IF EXISTS reviews;

-- check: should now list 9 tables
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;
