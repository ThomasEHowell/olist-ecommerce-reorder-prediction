SET search_path TO olist;
-- NOTE:
-- Update the file paths below to match your local environment
-- Can efficiently be done using the Pgadmin replace tool on:
-- '<PROJECT_ROOT>'

COPY product_category_name_translation
FROM '<PROJECT_ROOT>/olist_store_november_2025/data/raw/product_category_name_translation.csv'
WITH (FORMAT csv, HEADER true);

/****************************************************
Manually add missing translations not included
in the original Olist product_category_name_translation.csv.
*****************************************************/
INSERT INTO olist.product_category_name_translation (
    product_category_name,
    product_category_name_english
)
VALUES 
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_food_appliances'),
    ('pc_gamer', 'gaming_computer'),
	('unknown_category', 'unknown_category');
	

COPY products
FROM '<PROJECT_ROOT>/olist_store_november_2025/data/raw/olist_products_dataset.csv'
WITH (FORMAT csv, HEADER true);

/*****************************************************
Fill null instances of product_category_name 
with unknown_category
**************************************************/
UPDATE olist.products
SET product_category_name = 'unknown_category'
WHERE product_category_name IS NULL;

COPY customers
FROM '<PROJECT_ROOT>/olist_store_november_2025/data/raw/olist_customers_dataset.csv'
WITH (FORMAT csv, HEADER true);

COPY sellers
FROM '<PROJECT_ROOT>/olist_store_november_2025/data/raw/olist_sellers_dataset.csv'
WITH (FORMAT csv, HEADER true);

COPY geolocation
FROM '<PROJECT_ROOT>/olist_store_november_2025/data/raw/olist_geolocation_dataset.csv'
WITH (FORMAT csv, HEADER true);

COPY orders
FROM '<PROJECT_ROOT>/olist_store_november_2025/data/raw/olist_orders_dataset.csv'
WITH (FORMAT csv, HEADER true);

COPY order_items
FROM '<PROJECT_ROOT>/olist_store_november_2025/data/raw/olist_order_items_dataset.csv'
WITH (FORMAT csv, HEADER true);

COPY order_payments
FROM '<PROJECT_ROOT>/olist_store_november_2025/data/raw/olist_order_payments_dataset.csv'
WITH (FORMAT csv, HEADER true);

-- NOTE: This dataset was deduplicated in Python before loading.
-- See README for reproducibility details.
COPY order_reviews
FROM '<PROJECT_ROOT>/olist_store_november_2025/data/interim/deduped_olist_review_orders_dataset.csv'
WITH (FORMAT csv, HEADER true);

-- This is an extra table separate from the raw Olist dataset
-- Use for feature engineering
COPY olist.state_median_income
FROM '<PROJECT_ROOT>/olist_store_november_2025/data/raw/brazil_state_median_income_2017.csv'
WITH (FORMAT csv, HEADER true);