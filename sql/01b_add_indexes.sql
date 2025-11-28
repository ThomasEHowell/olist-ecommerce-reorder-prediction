/***************************************************************
File: 01b_add_indexes.sql
Purpose:
 - Add supporting indexes to improve join and filter performance
   for the Olist Analytical Base Table (ABT) build process.
 - Indexes cover customer, order, order items, payments, reviews,
   and product category translation keys.

Notes:
 - All statements use IF NOT EXISTS for safe re-runs.
 - Index names follow a consistent idx_<table>_<column> pattern.
***************************************************************/
CREATE INDEX IF NOT EXISTS idx_customers_customer_unique_id ON olist.customers (customer_unique_id);
CREATE INDEX IF NOT EXISTS idx_customers_state ON olist.customers (customer_state);

CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON olist.orders (customer_id);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON olist.order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON olist.order_items (product_id);
CREATE INDEX IF NOT EXISTS idx_order_items_seller_id ON olist.order_items (seller_id);

CREATE INDEX IF NOT EXISTS idx_order_payments_order_id ON olist.order_payments (order_id);

CREATE INDEX IF NOT EXISTS idx_order_reviews_order_id ON olist.order_reviews (order_id);

CREATE INDEX IF NOT EXISTS idx_products_product_category_name_ ON olist.products (product_category_name);

CREATE INDEX IF NOT EXISTS idx_pcnt_product_category_name_translation ON olist.product_category_name_translation (product_category_name_english);