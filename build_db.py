"""
build_db.py
-----------
Creates retail.db (SQLite) from the schema and loads the CSV data.
Run from the scripts/ directory:  python3 build_db.py
"""
import csv
import os
import sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
DB = os.path.join(ROOT, "retail.db")
DATA = os.path.join(ROOT, "data")
SCHEMA = os.path.join(ROOT, "sql", "01_schema.sql")

if os.path.exists(DB):
    os.remove(DB)

conn = sqlite3.connect(DB)
cur = conn.cursor()

with open(SCHEMA) as f:
    cur.executescript(f.read())
print("Schema created.")

def load(table, cols):
    path = os.path.join(DATA, f"{table}.csv")
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        rows = [tuple(r[c] for c in cols) for r in reader]
    ph = ",".join("?" * len(cols))
    cur.executemany(f"INSERT INTO {table} ({','.join(cols)}) VALUES ({ph})", rows)
    print(f"  loaded {len(rows):>8,} into {table}")

load("customers",  ["customer_id", "signup_date", "region", "acquisition_channel"])
load("products",   ["product_id", "product_name", "category", "unit_price", "unit_cost"])
load("orders",     ["order_id", "customer_id", "order_date", "status"])
load("order_items",["order_id", "product_id", "quantity", "unit_price", "unit_cost"])

conn.commit()
conn.close()
print(f"Database written to {DB}")
