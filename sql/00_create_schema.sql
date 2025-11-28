CREATE SCHEMA IF NOT EXISTS olist;
SET search_path TO olist;


-- Table: olist.product_category_name_translation

DROP TABLE IF EXISTS olist.product_category_name_translation;

CREATE TABLE IF NOT EXISTS olist.product_category_name_translation
(
    product_category_name text NOT NULL,
    product_category_name_english text,
    CONSTRAINT product_category_name_translation_pkey PRIMARY KEY (product_category_name)
);


-- Table: olist.products

DROP TABLE IF EXISTS olist.products;

CREATE TABLE IF NOT EXISTS olist.products
(
    product_id text NOT NULL,
    product_category_name text,
    product_name_lenght numeric,
    product_description_lenght numeric,
    product_photos_qty numeric,
    product_weight_g numeric,
    product_length_cm numeric,
    product_height_cm numeric,
    product_width_cm numeric,
    CONSTRAINT products_pkey PRIMARY KEY (product_id)
);


-- Table: olist.customers

DROP TABLE IF EXISTS olist.customers;

CREATE TABLE IF NOT EXISTS olist.customers
(
    customer_id text NOT NULL,
    customer_unique_id text,
    customer_zip_code_prefix text,
    customer_city text,
    customer_state text,
    CONSTRAINT customers_pkey PRIMARY KEY (customer_id)
);


-- Table: olist.orders

DROP TABLE IF EXISTS olist.orders;

CREATE TABLE IF NOT EXISTS olist.orders
(
    order_id text NOT NULL,
    customer_id text,
    order_status text,
    order_purchase_timestamp timestamp without time zone,
    order_approved_at timestamp without time zone,
    order_delivered_carrier_date timestamp without time zone,
    order_delivered_customer_date timestamp without time zone,
    order_estimated_delivery_date timestamp without time zone,
    CONSTRAINT orders_pkey PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
        REFERENCES olist.customers (customer_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);


-- Table: olist.sellers

DROP TABLE IF EXISTS olist.sellers;

CREATE TABLE IF NOT EXISTS olist.sellers
(
    seller_id text NOT NULL,
    seller_zip_code_prefix text,
    seller_city text,
    seller_state text,
    CONSTRAINT sellers_pkey PRIMARY KEY (seller_id)
);


-- Table: olist.order_items

DROP TABLE IF EXISTS olist.order_items;

CREATE TABLE IF NOT EXISTS olist.order_items
(
    order_id text NOT NULL,
    order_item_id numeric NOT NULL,
    product_id text,
    seller_id text,
    shipping_limit_date timestamp without time zone,
    price numeric,
    freight_value numeric,
    CONSTRAINT order_items_pkey PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_order_items_orders FOREIGN KEY (order_id)
        REFERENCES olist.orders (order_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fk_order_items_products FOREIGN KEY (product_id)
        REFERENCES olist.products (product_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fk_order_items_sellers FOREIGN KEY (seller_id)
        REFERENCES olist.sellers (seller_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);


-- Table: olist.order_payments

DROP TABLE IF EXISTS olist.order_payments;

CREATE TABLE IF NOT EXISTS olist.order_payments
(
    order_id text NOT NULL,
    payment_sequential numeric NOT NULL,
    payment_type text,
    payment_installments numeric,
    payment_value numeric,
    CONSTRAINT order_payments_pkey PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_order_payments_orders FOREIGN KEY (order_id)
        REFERENCES olist.orders (order_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);


-- Table: olist.order_reviews

DROP TABLE IF EXISTS olist.order_reviews;

CREATE TABLE IF NOT EXISTS olist.order_reviews
(
    order_id text NOT NULL,
    review_id text,
    review_score numeric,
    review_comment_title text,
    review_comment_message text,
    review_creation_date timestamp without time zone,
    review_answer_timestamp timestamp without time zone,
    CONSTRAINT order_reviews_pkey PRIMARY KEY (order_id),
    CONSTRAINT fk_order_reviews_orders FOREIGN KEY (order_id)
        REFERENCES olist.orders (order_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);


-- Table: olist.geolocation

DROP TABLE IF EXISTS olist.geolocation;

CREATE TABLE IF NOT EXISTS olist.geolocation
(
    zip_code_prefix text,
    latitude numeric,
    longitude numeric,
    city text,
    state text,
    geolocation_sk BIGSERIAL PRIMARY KEY
);


-- Table: olist.state_median_income (not part of the public Olist dataset)

DROP TABLE IF EXISTS olist.state_median_income;

CREATE TABLE olist.state_median_income (
    state_code CHAR(2) PRIMARY KEY,
    median_monthly_income_2017 NUMERIC(12,2)
);