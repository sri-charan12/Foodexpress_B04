"""Connections to PostgreSQL and MongoDB + status checks (used by every other file)."""
import os
from decimal import Decimal
from pathlib import Path

import pandas as pd
import psycopg
from dotenv import dotenv_values
from pymongo import MongoClient

# read .env straight from this folder (works even if started from another folder)
_env = dotenv_values(Path(__file__).resolve().parent / ".env", encoding="utf-8-sig")


def _get(key, default=""):
    return _env.get(key) or os.getenv(key, default)


PG = dict(
    host=_get("PG_HOST", "localhost"),
    port=_get("PG_PORT", "5432"),
    dbname=_get("PG_DB", "food_express"),
    user=_get("PG_USER", "postgres"),
    password=_get("Sricharan@12", ""),
    connect_timeout=3,
)
MONGO_URI = _get("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB = _get("MONGO_DB", "food_express_mongo")
USE_MONGO = _get("USE_MONGO", "true").strip().lower() == "true"

_mongo_client = None


# ---------------- PostgreSQL ----------------
def pg_conn():
    return psycopg.connect(**PG)


def pg_status():
    """Returns (True/False, message)."""
    conn = None
    try:
        conn = pg_conn()
        cur = conn.cursor()
        cur.execute("SELECT version()")
        return True, cur.fetchone()[0].split(" on ")[0]
    except Exception as e:
        return False, str(e).strip().splitlines()[0]
    finally:
        if conn:
            conn.close()


def query_pg(sql, params=None):
    """Run a SELECT and return a pandas DataFrame."""
    conn = pg_conn()
    try:
        cur = conn.cursor()
        cur.execute(sql, params)
        cols = [d[0] for d in cur.description]
        df = pd.DataFrame(cur.fetchall(), columns=cols)
    finally:
        conn.close()
    for c in df.columns:  # NUMERIC comes back as Decimal -> float for charts
        if df[c].map(lambda v: isinstance(v, Decimal)).any():
            df[c] = df[c].astype(float)
    return df


# ---------------- MongoDB ----------------
def mongo_client():
    global _mongo_client
    if _mongo_client is None:
        _mongo_client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=2000)
    return _mongo_client


def mongo_db():
    return mongo_client()[MONGO_DB]


def mongo_status():
    """Returns (True/False, message)."""
    if not USE_MONGO:
        return False, "Disabled (PostgreSQL-only mode)"
    try:
        c = mongo_client()
        c.admin.command("ping")
        return True, "MongoDB " + c.server_info()["version"]
    except Exception as e:
        return False, str(e).strip().splitlines()[0]