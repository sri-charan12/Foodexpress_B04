// =====================================================
// STAGE 3: MONGODB COLLECTIONS FOR FOOD EXPRESS
// Paste into mongosh (or MongoDB Compass > _MONGOSH at the bottom) and press Enter.
// Run this once. Re-running resets these 3 collections.
// =====================================================

// 1) In pgAdmin run:  SELECT delivery_agent_id FROM orders WHERE order_id = 3;
//    and put that number here (order 3 is the OUT_FOR_DELIVERY order):
const AGENT_ID = 1;

const mdb = db.getSiblingDB("food_express_mongo");
["menu_details", "order_tracking", "agent_locations"].forEach(c => mdb[c].drop());

// ---- 1. menu_details : extra info per menu item (item_id links to PostgreSQL menu_items) ----
mdb.menu_details.insertMany([
  { item_id: 1,  item_name: "Paneer Tikka",      ingredients: ["paneer", "yogurt", "spices"],     allergens: ["dairy"], spice_level: "medium", veg: true,  calories: 320 },
  { item_id: 2,  item_name: "Chicken 65",        ingredients: ["chicken", "curry leaves", "chilli"], allergens: [],     spice_level: "hot",    veg: false, calories: 380 },
  { item_id: 3,  item_name: "Butter Chicken",    ingredients: ["chicken", "butter", "tomato", "cream"], allergens: ["dairy"], spice_level: "medium", veg: false, calories: 520 },
  { item_id: 4,  item_name: "Dal Tadka",         ingredients: ["lentils", "garlic", "ghee"],       allergens: ["dairy"], spice_level: "mild",   veg: true,  calories: 280 },
  { item_id: 5,  item_name: "Gulab Jamun",       ingredients: ["milk solids", "sugar syrup"],      allergens: ["dairy", "gluten"], spice_level: "mild", veg: true, calories: 300 },
  { item_id: 6,  item_name: "Chocolate Brownie", ingredients: ["chocolate", "flour", "eggs"],      allergens: ["gluten", "nuts"], spice_level: "mild", veg: false, calories: 410 },
  { item_id: 7,  item_name: "Cold Coffee",       ingredients: ["coffee", "milk", "ice"],           allergens: ["dairy"], spice_level: "mild",   veg: true,  calories: 180 },
  { item_id: 8,  item_name: "Mango Lassi",       ingredients: ["mango", "yogurt"],                 allergens: ["dairy"], spice_level: "mild",   veg: true,  calories: 220 },
  { item_id: 9,  item_name: "Chicken Biryani",   ingredients: ["basmati rice", "chicken", "saffron", "spices"], allergens: [], spice_level: "hot", veg: false, calories: 650 },
  { item_id: 10, item_name: "Veg Biryani",       ingredients: ["basmati rice", "vegetables", "spices"], allergens: [], spice_level: "medium", veg: true, calories: 520 }
]);
mdb.menu_details.createIndex({ item_id: 1 }, { unique: true });

// ---- 2. order_tracking : status events per order (order_id links to PostgreSQL orders) ----
const flow = ["PLACED", "PREPARING", "OUT_FOR_DELIVERY", "DELIVERED"];
const finalStatus = { 1: "PLACED", 2: "PREPARING", 3: "OUT_FOR_DELIVERY", 4: "CANCELLED" };
const base = new Date();
const tracking = [];
for (let id = 1; id <= 10; id++) {
  const last = finalStatus[id] || "DELIVERED";
  const steps = last === "CANCELLED" ? ["PLACED", "CANCELLED"] : flow.slice(0, flow.indexOf(last) + 1);
  tracking.push({
    order_id: id,
    events: steps.map((s, i) => ({ status: s, time: new Date(base.getTime() - (steps.length - i) * 12 * 60000) }))
  });
}
mdb.order_tracking.insertMany(tracking);
mdb.order_tracking.createIndex({ order_id: 1 }, { unique: true });

// ---- 3. agent_locations : GPS points of the delivery agent (order_id, agent_id link to PostgreSQL) ----
const start = [16.5193, 80.6305], end = [16.5062, 80.6480];   // demo points in Vijayawada
const pts = [];
for (let i = 0; i <= 14; i++) {
  const t = i / 14;
  const lat = start[0] + (end[0] - start[0]) * t;
  const lng = start[1] + (end[1] - start[1]) * t;
  pts.push({
    order_id: 3, agent_id: AGENT_ID, lat: lat, lng: lng,
    location: { type: "Point", coordinates: [lng, lat] },
    speed_kmph: 20 + (i % 5) * 3,
    ts: new Date(base.getTime() - (14 - i) * 3000)
  });
}
mdb.agent_locations.insertMany(pts);
mdb.agent_locations.createIndex({ location: "2dsphere" });
mdb.agent_locations.createIndex({ order_id: 1, ts: 1 });

// ---- check ----
printjson({
  menu_details: mdb.menu_details.countDocuments(),
  order_tracking: mdb.order_tracking.countDocuments(),
  agent_locations: mdb.agent_locations.countDocuments()
});
