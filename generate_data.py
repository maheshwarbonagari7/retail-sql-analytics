"""
generate_data.py
------------------
Generates a realistic synthetic dataset for a fictional UK online retailer
("Northwind Retail Co."). Output is four CSV files in ../data.

The data is engineered to contain genuine, discoverable patterns:
  - steady customer growth month on month
  - Q4 seasonal uplift (Black Friday / Christmas)
  - retention decay (cohorts shrink over time, but at a realistic rate)
  - category and regional mix

Everything is seeded so the dataset is fully reproducible.
"""

import csv
import os
import random
from datetime import date, timedelta

import numpy as np

SEED = 42
random.seed(SEED)
np.random.seed(SEED)

HERE = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(HERE, "..", "data")
os.makedirs(DATA_DIR, exist_ok=True)

# ----------------------------------------------------------------------
# Reference data
# ----------------------------------------------------------------------
START = date(2023, 1, 1)
END = date(2025, 12, 31)

REGIONS = [
    ("North East", 0.08), ("North West", 0.14), ("Yorkshire", 0.11),
    ("Midlands", 0.15), ("East", 0.09), ("London", 0.18),
    ("South East", 0.13), ("South West", 0.07), ("Scotland", 0.04),
    ("Wales", 0.01),
]
CHANNELS = [("Organic Search", 0.34), ("Paid Search", 0.22),
            ("Social", 0.18), ("Email", 0.14), ("Referral", 0.12)]

CATEGORIES = [
    # (category, base_price, margin)
    ("Home & Kitchen", 28.0, 0.42),
    ("Electronics", 95.0, 0.22),
    ("Clothing", 32.0, 0.55),
    ("Health & Beauty", 18.0, 0.50),
    ("Sports & Outdoor", 45.0, 0.38),
    ("Books & Media", 12.0, 0.30),
]


def weighted_choice(pairs):
    items, weights = zip(*pairs)
    return random.choices(items, weights=weights, k=1)[0]


def month_index(d):
    return (d.year - START.year) * 12 + (d.month - START.month)


# ----------------------------------------------------------------------
# 1. Products
# ----------------------------------------------------------------------
products = []
pid = 1000
for cat, base, margin in CATEGORIES:
    n = random.randint(12, 20)
    for _ in range(n):
        price = round(base * np.random.uniform(0.5, 2.2), 2)
        cost = round(price * (1 - margin) * np.random.uniform(0.9, 1.1), 2)
        products.append({
            "product_id": pid,
            "product_name": f"{cat.split(' ')[0]} Item {pid}",
            "category": cat,
            "unit_price": price,
            "unit_cost": min(cost, round(price * 0.95, 2)),
        })
        pid += 1

# ----------------------------------------------------------------------
# 2. Customers  (growing acquisition over time)
# ----------------------------------------------------------------------
customers = []
cid = 10000
total_months = month_index(END) + 1
# acquisition grows ~3% per month off a base, with Q4 spikes
base_acq = 90
for m in range(total_months):
    d0 = date(START.year + (START.month - 1 + m) // 12,
              (START.month - 1 + m) % 12 + 1, 1)
    growth = base_acq * (1.03 ** m)
    seasonal = 1.6 if d0.month in (11, 12) else 1.0
    n_new = int(growth * seasonal * np.random.uniform(0.9, 1.1))
    for _ in range(n_new):
        day = random.randint(1, 28)
        signup = date(d0.year, d0.month, day)
        customers.append({
            "customer_id": cid,
            "signup_date": signup.isoformat(),
            "region": weighted_choice(REGIONS),
            "acquisition_channel": weighted_choice(CHANNELS),
        })
        cid += 1

# ----------------------------------------------------------------------
# 3. Orders + order items  (with retention decay + seasonality)
# ----------------------------------------------------------------------
orders = []
order_items = []
oid = 500000
STATUS = [("completed", 0.93), ("returned", 0.05), ("cancelled", 0.02)]

for c in customers:
    signup = date.fromisoformat(c["signup_date"])
    # each customer has a "loyalty" propensity
    loyalty = np.random.beta(2, 5)            # most low, some high
    # expected number of repeat purchases driven by loyalty
    n_orders = 1 + np.random.poisson(loyalty * 6)
    last = signup
    for k in range(n_orders):
        if k == 0:
            order_date = signup + timedelta(days=random.randint(0, 3))
        else:
            # gap grows over time (retention decay), with noise
            gap = int(np.random.exponential(35 + k * 12))
            order_date = last + timedelta(days=max(3, gap))
        if order_date > END:
            break
        last = order_date
        # Q4 uplift in basket size
        seasonal = 1.35 if order_date.month in (11, 12) else 1.0
        status = weighted_choice(STATUS)
        n_lines = max(1, int(np.random.poisson(2 * seasonal)))
        oid += 1
        chosen = random.sample(products, min(n_lines, len(products)))
        for p in chosen:
            qty = int(np.random.choice([1, 1, 1, 2, 2, 3], 1)[0])
            order_items.append({
                "order_id": oid,
                "product_id": p["product_id"],
                "quantity": qty,
                "unit_price": p["unit_price"],
                "unit_cost": p["unit_cost"],
            })
        orders.append({
            "order_id": oid,
            "customer_id": c["customer_id"],
            "order_date": order_date.isoformat(),
            "status": status,
        })

# ----------------------------------------------------------------------
# Write CSVs
# ----------------------------------------------------------------------
def write_csv(name, rows, fields):
    path = os.path.join(DATA_DIR, name)
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)
    print(f"  {name:20s} {len(rows):>8,} rows")


print("Generating dataset...")
write_csv("products.csv", products,
          ["product_id", "product_name", "category", "unit_price", "unit_cost"])
write_csv("customers.csv", customers,
          ["customer_id", "signup_date", "region", "acquisition_channel"])
write_csv("orders.csv", orders,
          ["order_id", "customer_id", "order_date", "status"])
write_csv("order_items.csv", order_items,
          ["order_id", "product_id", "quantity", "unit_price", "unit_cost"])
print("Done.")
