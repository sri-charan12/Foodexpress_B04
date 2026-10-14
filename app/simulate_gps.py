"""Simulates a delivery agent's GPS tracker writing points into MongoDB every few seconds.
Usage:  python simulate_gps.py            (uses the first OUT_FOR_DELIVERY order)
        python simulate_gps.py 42         (a specific order id)
A real agent app would send the same documents (lat, lng, time) from the phone.
"""
import random
import sys
import time
from datetime import datetime, timezone

from db import mongo_db, query_pg

START = (16.5193, 80.6305)   # demo restaurant location (Vijayawada)
END = (16.5062, 80.6480)     # demo customer location
STEPS, DELAY = 40, 3

if len(sys.argv) > 1:
    order_id = int(sys.argv[1])
else:
    df = query_pg("SELECT order_id FROM orders WHERE order_status='OUT_FOR_DELIVERY' AND delivery_agent_id IS NOT NULL ORDER BY order_id LIMIT 1")
    if df.empty:
        sys.exit("No OUT_FOR_DELIVERY order found. Pass an order id.")
    order_id = int(df.order_id[0])

row = query_pg("SELECT delivery_agent_id FROM orders WHERE order_id=%s", (order_id,))
if row.empty or row.delivery_agent_id[0] is None:
    sys.exit("That order has no delivery agent.")
agent_id = int(row.delivery_agent_id[0])

col = mongo_db().agent_locations
col.delete_many({"order_id": order_id})   # restart the route
print(f"Tracking order {order_id}, agent {agent_id}. Ctrl+C to stop.")

for i in range(STEPS + 1):
    t = i / STEPS
    lat = START[0] + (END[0] - START[0]) * t + random.uniform(-0.0002, 0.0002)
    lng = START[1] + (END[1] - START[1]) * t + random.uniform(-0.0002, 0.0002)
    col.insert_one({
        "order_id": order_id,
        "agent_id": agent_id,
        "lat": lat,
        "lng": lng,
        "location": {"type": "Point", "coordinates": [lng, lat]},
        "speed_kmph": round(random.uniform(18, 35), 1),
        "ts": datetime.now(timezone.utc),
    })
    print(f"point {i}/{STEPS}: {lat:.5f}, {lng:.5f}")
    time.sleep(DELAY)
print("Delivered (route finished).")
