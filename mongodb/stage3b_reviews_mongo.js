// =====================================================
// STAGE 3b: REVIEWS MOVED TO MONGODB
// Paste into mongosh (or Compass > _MONGOSH). Run once; re-running resets this collection.
// These are the same 30 reviews that were in the PostgreSQL reviews table.
// customer_id, restaurant_id and order_id link back to PostgreSQL.
// =====================================================

const mdb = db.getSiblingDB("food_express_mongo");
mdb.reviews.drop();

mdb.reviews.insertMany([
  { customer_id: 57, restaurant_id: 70, order_id: 6, rating: 5, review_text: "Excellent food, fast delivery", review_date: new Date("2026-07-05T04:10:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 86, restaurant_id: 71, order_id: 8, rating: 5, review_text: "Excellent food, fast delivery", review_date: new Date("2026-07-06T14:00:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 15, restaurant_id: 14, order_id: 10, rating: 3, review_text: "Average, was a bit cold", review_date: new Date("2026-07-08T00:16:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 36, restaurant_id: 6, order_id: 16, rating: 5, review_text: "Excellent food, fast delivery", review_date: new Date("2026-07-12T06:27:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 21, restaurant_id: 95, order_id: 18, rating: 4, review_text: "Tasty and fresh", review_date: new Date("2026-07-13T16:16:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 15, restaurant_id: 10, order_id: 20, rating: 3, review_text: "Okay for the price", review_date: new Date("2026-07-15T02:00:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 46, restaurant_id: 100, order_id: 26, rating: 4, review_text: "Very good, slightly delayed", review_date: new Date("2026-07-19T08:06:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 31, restaurant_id: 21, order_id: 28, rating: 5, review_text: "Loved it, will order again", review_date: new Date("2026-07-20T18:09:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 43, restaurant_id: 53, order_id: 30, rating: 4, review_text: "Tasty and fresh", review_date: new Date("2026-07-22T04:47:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 25, restaurant_id: 52, order_id: 36, rating: 5, review_text: "Excellent food, fast delivery", review_date: new Date("2026-07-26T10:42:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 83, restaurant_id: 66, order_id: 38, rating: 4, review_text: "Very good, slightly delayed", review_date: new Date("2026-07-27T20:22:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 34, restaurant_id: 23, order_id: 40, rating: 4, review_text: "Very good, slightly delayed", review_date: new Date("2026-07-29T06:07:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 1, restaurant_id: 67, order_id: 46, rating: 3, review_text: "Average, was a bit cold", review_date: new Date("2026-08-02T12:27:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 26, restaurant_id: 47, order_id: 48, rating: 5, review_text: "Loved it, will order again", review_date: new Date("2026-08-03T22:42:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 85, restaurant_id: 16, order_id: 50, rating: 5, review_text: "Excellent food, fast delivery", review_date: new Date("2026-08-05T08:20:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 39, restaurant_id: 52, order_id: 56, rating: 5, review_text: "Excellent food, fast delivery", review_date: new Date("2026-08-09T14:36:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 56, restaurant_id: 75, order_id: 58, rating: 4, review_text: "Tasty and fresh", review_date: new Date("2026-08-11T00:13:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 87, restaurant_id: 28, order_id: 60, rating: 4, review_text: "Very good, slightly delayed", review_date: new Date("2026-08-12T10:28:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 6, restaurant_id: 32, order_id: 66, rating: 4, review_text: "Tasty and fresh", review_date: new Date("2026-08-16T16:01:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 81, restaurant_id: 74, order_id: 68, rating: 4, review_text: "Tasty and fresh", review_date: new Date("2026-08-18T02:26:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 32, restaurant_id: 19, order_id: 70, rating: 3, review_text: "Okay for the price", review_date: new Date("2026-08-19T12:25:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 60, restaurant_id: 86, order_id: 76, rating: 4, review_text: "Very good, slightly delayed", review_date: new Date("2026-08-23T18:51:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 57, restaurant_id: 79, order_id: 78, rating: 3, review_text: "Average, was a bit cold", review_date: new Date("2026-08-25T04:57:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 21, restaurant_id: 96, order_id: 80, rating: 4, review_text: "Tasty and fresh", review_date: new Date("2026-08-26T14:28:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 43, restaurant_id: 41, order_id: 86, rating: 3, review_text: "Okay for the price", review_date: new Date("2026-08-30T20:17:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 89, restaurant_id: 20, order_id: 88, rating: 5, review_text: "Excellent food, fast delivery", review_date: new Date("2026-09-01T06:24:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 70, restaurant_id: 60, order_id: 90, rating: 5, review_text: "Excellent food, fast delivery", review_date: new Date("2026-09-02T16:21:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 95, restaurant_id: 70, order_id: 96, rating: 4, review_text: "Very good, slightly delayed", review_date: new Date("2026-09-06T22:47:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 56, restaurant_id: 63, order_id: 98, rating: 5, review_text: "Loved it, will order again", review_date: new Date("2026-09-08T08:17:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null },
  { customer_id: 52, restaurant_id: 93, order_id: 100, rating: 3, review_text: "Okay for the price", review_date: new Date("2026-09-09T18:51:00Z"), tags: [], photos: [], helpful_votes: 0, restaurant_reply: null }
]);

mdb.reviews.createIndex({ order_id: 1 }, { unique: true });   // one review per order
mdb.reviews.createIndex({ restaurant_id: 1 });
mdb.reviews.createIndex({ rating: 1 });

print("reviews:", mdb.reviews.countDocuments());   // expect 30

// ---------- replacements for the old SQL review queries ----------
// Average rating per restaurant (restaurant names live in PostgreSQL, so the app joins by restaurant_id)
// mdb.reviews.aggregate([
//   { $group: { _id: "$restaurant_id", avg_rating: { $avg: "$rating" }, reviews: { $sum: 1 } } },
//   { $sort: { avg_rating: -1 } }
// ]);

// Restaurants rated above the overall average
// const overall = mdb.reviews.aggregate([{ $group: { _id: null, a: { $avg: "$rating" } } }]).toArray()[0].a;
// mdb.reviews.aggregate([
//   { $group: { _id: "$restaurant_id", avg_rating: { $avg: "$rating" } } },
//   { $match: { avg_rating: { $gt: overall } } }
// ]);

// Review of one order
// mdb.reviews.findOne({ order_id: 4 });

// Add a restaurant reply (shows why documents are flexible)
// mdb.reviews.updateOne({ order_id: 4 }, { $set: { restaurant_reply: "Thank you!" }, $inc: { helpful_votes: 1 } });
