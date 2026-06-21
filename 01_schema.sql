-- ============================================================
-- 01_schema.sql
-- Schema for Northwind Retail Co. analytics database (SQLite)
-- ============================================================

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;

CREATE TABLE customers (
    customer_id         INTEGER PRIMARY KEY,
    signup_date         DATE    NOT NULL,
    region              TEXT    NOT NULL,
    acquisition_channel TEXT    NOT NULL
);

CREATE TABLE products (
    product_id   INTEGER PRIMARY KEY,
    product_name TEXT    NOT NULL,
    category     TEXT    NOT NULL,
    unit_price   REAL    NOT NULL,
    unit_cost    REAL    NOT NULL
);

CREATE TABLE orders (
    order_id    INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date  DATE    NOT NULL,
    status      TEXT    NOT NULL          -- completed | returned | cancelled
);

CREATE TABLE order_items (
    order_id   INTEGER NOT NULL REFERENCES orders(order_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity   INTEGER NOT NULL,
    unit_price REAL    NOT NULL,
    unit_cost  REAL    NOT NULL
);

-- Indexes to support the analytical queries
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date     ON orders(order_date);
CREATE INDEX idx_items_order      ON order_items(order_id);
CREATE INDEX idx_items_product    ON order_items(product_id);
