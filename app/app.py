"""Streamlit frontend connected to PostgreSQL (MongoDB optional).
Run:  streamlit run app.py
"""
import pandas as pd
import streamlit as st

from db import mongo_db, mongo_status, pg_status, query_pg

st.set_page_config(page_title="Food Express", page_icon="🍔", layout="wide")


@st.cache_data(ttl=5)
def statuses():
    return pg_status(), mongo_status()


# ---------------- sidebar: connection status ----------------
if st.sidebar.button("Refresh connection status"):
    st.cache_data.clear()
(pg_ok, pg_msg), (mg_ok, mg_msg) = statuses()

st.sidebar.title("Food Express")
st.sidebar.subheader("Database status")
for name, ok, msg in (("PostgreSQL", pg_ok, pg_msg), ("MongoDB", mg_ok, mg_msg)):
    (st.sidebar.success if ok else st.sidebar.error)(f"{name}: {'Connected' if ok else 'Not connected'}")
    st.sidebar.caption(msg[:110])

pages = ["Dashboard", "Orders", "Menu", "Order 360"] + (["Agent tracking"] if mg_ok else [])
page = st.sidebar.radio("Page", pages)


def need(pg=False, mongo=False):
    """Show a warning and return False if a required database is down."""
    ok = True
    if pg and not pg_ok:
        st.warning("PostgreSQL is not connected. Check your .env file.")
        ok = False
    if mongo and not mg_ok:
        st.warning("MongoDB is not connected.")
        ok = False
    return ok


# ---------------- pages ----------------
def dashboard():
    st.title("Dashboard")
    c1, c2 = st.columns(2)
    c1.metric("PostgreSQL", "Connected" if pg_ok else "Not connected")
    c2.metric("MongoDB", "Connected" if mg_ok else "Not connected")
    if need(pg=True):
        n = query_pg("""SELECT (SELECT COUNT(*) FROM restaurants) AS restaurants,
                               (SELECT COUNT(*) FROM customers) AS customers,
                               (SELECT COUNT(*) FROM orders) AS orders,
                               (SELECT COALESCE(SUM(amount),0) FROM payments WHERE payment_status='SUCCESS') AS revenue""").iloc[0]
        a, b, c, d = st.columns(4)
        a.metric("Restaurants", int(n.restaurants))
        b.metric("Customers", int(n.customers))
        c.metric("Orders", int(n.orders))
        d.metric("Revenue (paid)", f"{n.revenue:,.0f}")
        st.subheader("Orders by status")
        st.bar_chart(query_pg("SELECT order_status, COUNT(*) AS total FROM orders GROUP BY order_status").set_index("order_status"))
    if mg_ok:
        db = mongo_db()
        st.subheader("MongoDB collections")
        st.write({c: db[c].count_documents({}) for c in ("menu_details", "order_tracking", "agent_locations")})


def orders():
    st.title("Orders (PostgreSQL)")
    if not need(pg=True):
        return
    status = st.selectbox("Status", ["ALL", "PLACED", "PREPARING", "OUT_FOR_DELIVERY", "DELIVERED", "CANCELLED"])
    sql = """SELECT o.order_id, cu.customer_name, r.restaurant_name, o.order_status, o.order_date,
                    p.amount, p.payment_method, p.payment_status
             FROM orders o
             JOIN customers cu ON cu.customer_id = o.customer_id
             JOIN restaurants r ON r.restaurant_id = o.restaurant_id
             LEFT JOIN payments p ON p.order_id = o.order_id"""
    params = None
    if status != "ALL":
        sql += " WHERE o.order_status = %s"
        params = (status,)
    st.dataframe(query_pg(sql + " ORDER BY o.order_id LIMIT 300", params), use_container_width=True)


def menu():
    st.title("Menu (PostgreSQL" + (" + MongoDB)" if mg_ok else ")"))
    if not need(pg=True):
        return
    rests = query_pg("SELECT restaurant_id, restaurant_name FROM restaurants ORDER BY restaurant_name")
    name = st.selectbox("Restaurant", rests.restaurant_name)
    rid = int(rests[rests.restaurant_name == name].restaurant_id.iloc[0])
    df = query_pg("""SELECT mi.item_id, mi.item_name, mc.category_name, mi.price, mi.is_available
                     FROM menu_items mi JOIN menu_categories mc ON mc.category_id = mi.category_id
                     WHERE mi.restaurant_id = %s ORDER BY mi.item_id""", (rid,))
    if mg_ok:
        docs = list(mongo_db().menu_details.find({"item_id": {"$in": df.item_id.astype(int).tolist()}}, {"_id": 0, "item_name": 0}))
        if docs:
            df = df.merge(pd.DataFrame(docs), on="item_id", how="left")
    else:
        st.info("MongoDB is off, so ingredient details are hidden.")
    st.dataframe(df, use_container_width=True)


@st.fragment(run_every=3)
def live_map(order_id):
    pts = list(mongo_db().agent_locations.find({"order_id": int(order_id)}, {"_id": 0}).sort("ts", 1))
    if not pts:
        st.info("No GPS points yet. Run:  python simulate_gps.py " + str(order_id))
        return
    df = pd.DataFrame(pts)
    last = df.iloc[-1]
    a, b, c = st.columns(3)
    a.metric("Latest latitude", f"{last.lat:.5f}")
    b.metric("Latest longitude", f"{last.lng:.5f}")
    c.metric("Speed (km/h)", last.speed_kmph)
    st.map(df.rename(columns={"lat": "latitude", "lng": "longitude"})[["latitude", "longitude"]], zoom=13)
    st.caption(f"{len(df)} GPS points | last update {last.ts} | refreshes every 3 seconds")


def tracking():
    st.title("Delivery agent tracking")
    if not need(pg=True, mongo=True):
        return
    df = query_pg("""SELECT o.order_id, o.order_status, da.agent_name, da.vehicle_type
                     FROM orders o JOIN delivery_agents da ON da.agent_id = o.delivery_agent_id
                     WHERE o.order_status IN ('OUT_FOR_DELIVERY','DELIVERED') ORDER BY o.order_id""")
    if df.empty:
        st.info("No orders with an agent.")
        return
    pick = st.selectbox("Order", df.order_id, format_func=lambda i: "Order {} | {} | {} ({})".format(
        i, *df[df.order_id == i][["order_status", "agent_name", "vehicle_type"]].iloc[0]))
    live_map(int(pick))


def order360():
    st.title("Order 360")
    if not need(pg=True):
        return
    oid = st.number_input("Order id", min_value=1, value=1, step=1)
    head = query_pg("""SELECT o.order_id, cu.customer_name, r.restaurant_name, o.order_status,
                              da.agent_name, p.amount, p.payment_status
                       FROM orders o JOIN customers cu ON cu.customer_id = o.customer_id
                       JOIN restaurants r ON r.restaurant_id = o.restaurant_id
                       LEFT JOIN delivery_agents da ON da.agent_id = o.delivery_agent_id
                       LEFT JOIN payments p ON p.order_id = o.order_id WHERE o.order_id = %s""", (int(oid),))
    if head.empty:
        st.error("Order not found.")
        return
    st.subheader("From PostgreSQL")
    st.dataframe(head, use_container_width=True)
    st.dataframe(query_pg("""SELECT mi.item_name, oi.quantity, oi.unit_price, oi.quantity*oi.unit_price AS amount
                             FROM order_items oi JOIN menu_items mi ON mi.item_id = oi.item_id
                             WHERE oi.order_id = %s""", (int(oid),)), use_container_width=True)
    if mg_ok:
        st.subheader("From MongoDB")
        tr = mongo_db().order_tracking.find_one({"order_id": int(oid)}, {"_id": 0})
        st.dataframe(pd.DataFrame(tr["events"]) if tr else pd.DataFrame(), use_container_width=True)
        last = mongo_db().agent_locations.find_one({"order_id": int(oid)}, {"_id": 0, "location": 0}, sort=[("ts", -1)])
        st.write("Last GPS point:", last if last else "none yet")


{"Dashboard": dashboard, "Orders": orders, "Menu": menu, "Agent tracking": tracking, "Order 360": order360}[page]()