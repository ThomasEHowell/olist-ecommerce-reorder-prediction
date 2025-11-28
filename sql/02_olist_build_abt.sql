/***************************************************************
File: build_olist_abt
Table: olist.abt_customer_reorder_180d
Author: Thomas Howell
Created: 2025-11-15

Purpose:
 - Build the base customer spine for modeling
 - Append the target label (whether or not the customer reordered within 
 180 days of their first delivered purchase)
 -Append first-order: delivery, pricing, and review features

Current Output Grain:
 One row per unique customer (customer_unique_id)
 representing their first delivered order
***************************************************************/

DROP TABLE olist.abt_customer_reorder_180d;
CREATE TABLE olist.abt_customer_reorder_180d AS

/****************************************************
CTE: dataset_bounds
WHAT: Define dataset end date and latest allowed first order
WHY: Ensure every unique customer has a full 180-day reorder window
GRAIN: Single-row reference table
*****************************************************/
WITH dataset_bounds AS(SELECT 
	TIMESTAMP '2018-08-15' AS dataset_end,
	TIMESTAMP '2018-08-15' - INTERVAL '180 DAYS' AS first_order_cutoff_date
),

/****************************************************
CTE: customer_unique_order_sequential
WHAT: Assign an order sequential to each delivered order 
	by each unique customer
WHY: Used to identify each unique customer's first order
GRAIN: Order-level (one row per order)
*****************************************************/
customer_unique_order_sequential AS (
	SELECT 
	 c.customer_id, c.customer_unique_id, 
	 o.order_id, o.order_purchase_timestamp,
	 ROW_NUMBER() 
	 OVER(PARTITION BY c.customer_unique_id ORDER BY o.order_purchase_timestamp)
	 AS order_sequential
	FROM olist.customers c
	JOIN olist.orders o
		ON c.customer_id = o.customer_id
	WHERE o.order_status = 'delivered'
	AND o.order_delivered_customer_date <= (SELECT dataset_end FROM dataset_bounds)
),

/****************************************************
CTE: spine
WHAT: One row per customer representing their first delivered order
WHY: Serves as the customer spine and anchor timestamp for the label and features
GRAIN: Unique customer level (one row per unique customer)
*****************************************************/
spine AS (SELECT
	 customer_id,
     customer_unique_id, 
	 order_id AS first_order_id,
	 order_purchase_timestamp AS first_order_timestamp
	FROM customer_unique_order_sequential
	WHERE order_sequential = 1
	AND order_purchase_timestamp <= (SELECT first_order_cutoff_date FROM dataset_bounds)
),

/****************************************************
CTE: reorders
WHAT: For each spine customer, classify all delivered orders as
	to whether or not it is within 180 days of the first order
WHY: Intermediate order-level step before creating 
	a unique customer-level label
GRAIN: Order-level (one row per order for each spine customer)
*****************************************************/
reorders AS(
	SELECT 
	 s.customer_unique_id, s.first_order_id, s.first_order_timestamp,
	 CASE
	 	WHEN order_purchase_timestamp > first_order_timestamp
		AND order_purchase_timestamp <= (first_order_timestamp + INTERVAL '180 DAYS')
		AND order_id <> s.first_order_id
		 THEN 1
		 ELSE 0
	 END AS reordered_180d
	FROM spine s
	INNER JOIN olist.customers c
	ON s.customer_unique_id = c.customer_unique_id
	INNER JOIN olist.orders o
		ON c.customer_id = o.customer_id
	WHERE o.order_status = 'delivered'
	AND o.order_delivered_customer_date <= (SELECT dataset_end FROM dataset_bounds)
),

/****************************************************
CTE: reorder_label
WHAT: Aggregate per-order reorder flags into a 
	customer-level label indicating whether or not
	that customer reordered within 180 days of their first order.
WHY: Defines the target variable for modeling
GRAIN: Unique customer-level
*****************************************************/
reorder_label AS(
	SELECT
	 customer_unique_id, first_order_id, first_order_timestamp,
	 MAX(reordered_180d) AS reordered_180d
	FROM reorders
	GROUP BY customer_unique_id, first_order_id, first_order_timestamp
),

/***************************************************
CTE: first_order_delivery_features
WHAT: Delivery timing metrics for each customer's first order
WHY: Capture delivery timing as potential driver of reorders
GRAIN: First order-level (one row per first_order_id)
**************************************************/
first_order_delivery_features AS(
	SELECT
	 s.customer_unique_id, s.first_order_id, s.first_order_timestamp,
	 o.order_delivered_customer_date,
	 o.order_estimated_delivery_date,
	 EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0 
	 AS days_to_deliver,
	 EXTRACT(EPOCH FROM(o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 
	 AS actual_vs_estimated_delivery_days
	FROM spine s
	LEFT JOIN olist.orders o
		ON s.first_order_id = o.order_id

),

/***************************************************
CTE: first_order_items_features
WHAT: Delivery quantity and pricing metrics for each customer's first order
WHY: Capture item quantity and price info as potential predictor of reorders
GRAIN: First order-level (one row per first_order_id)
**************************************************/
first_order_items_features AS(
	SELECT
	 s.customer_unique_id, s.first_order_id, 
	 COUNT(oi.order_item_id) AS first_order_item_count,
	 SUM(oi.price) AS first_order_price,
	 SUM(oi.freight_value) / SUM(oi.price) as freight_price_ratio
	FROM spine s
	LEFT JOIN olist.order_items oi
		ON s.first_order_id = oi.order_id
	GROUP BY customer_unique_id, first_order_id
),

/***************************************************
CTE: first_order_reviews_features
WHAT: Customer review metrics for each customer's first order
WHY: Capture review metrics as potential predictor of reorders
GRAIN: First order-level (0-1 reviews for each first_order_id)
**************************************************/
first_order_reviews_features AS(
	SELECT
	 s.customer_unique_id, s.first_order_id,
	 r.review_score AS first_order_review_score,
	 CASE WHEN r.review_comment_message IS NOT NULL THEN 1 ELSE 0 END AS review_comment_flag,
	 LENGTH(r.review_comment_message) AS review_comment_length,
	 EXTRACT(EPOCH FROM(r.review_answer_timestamp - r.review_creation_date))
	 / 86400.0 AS review_response_delay_days
	FROM spine s
	LEFT JOIN olist.order_reviews r
		ON s.first_order_id = r.order_id
),

/****************************************************
CTE: first_order_payments_features
WHAT: Derive payment behavior features for each customer's first order
WHY: Capture payment method complexity and patterns that may relate 
     to reorder behavior
GRAIN: Unique customer-level (one row per unique customer / first order)
*****************************************************/
first_order_payments_features AS (
	SELECT
	 s.customer_unique_id, s.first_order_id,
	 MODE() WITHIN GROUP (ORDER BY op.payment_type) AS primary_payment_type,
	 MAX(op.payment_installments) AS count_payment_installments,
	 MAX(op.payment_sequential) AS count_payment_sequential,
	 CASE 
	 	WHEN COUNT(DISTINCT op.payment_type) > 1 THEN 1 ELSE 0 
	 	END AS used_multiple_payment_types
	FROM spine s
	    LEFT JOIN olist.order_payments op
	        ON s.first_order_id = op.order_id
	GROUP BY
	        s.customer_unique_id,
	        s.first_order_id,
	        s.first_order_timestamp
),

/****************************************************
CTE: first_order_category
WHAT: Map each customer's first delivered order to a single
      dominant product category (by highest item price)
WHY: Captures what type of product they initially bought
GRAIN: Unique customer-level (one row per customer / first order)
*****************************************************/
first_order_category AS (
    SELECT
        customer_unique_id,
        first_order_id,
        product_category_name AS first_order_category_portuguese,
		first_order_category_english -------------
    FROM (
        SELECT
            s.customer_unique_id,
            s.first_order_id,
            p.product_category_name,
			product_category_name_english AS first_order_category_english, ----------
            ROW_NUMBER() OVER (
                PARTITION BY s.first_order_id
                ORDER BY oi.price DESC
            ) AS category_rank
        FROM spine s
        JOIN olist.order_items oi
            ON s.first_order_id = oi.order_id
        JOIN olist.products p
            ON oi.product_id = p.product_id
		JOIN olist.product_category_name_translation pcnt ------------
			ON p.product_category_name = pcnt.product_category_name -----------
    ) ranked_categories
    WHERE category_rank = 1
),

/****************************************************
CTE: category_reorder_rate
WHAT: Compute the 180-day reorder rate for each first-order
      product category across all customers
WHY: Encodes how "reorder-prone" each category is at the
     population level (target encoding)
GRAIN: Product-category level (one row per category)
*****************************************************/

category_reorder_rate AS (
    SELECT
        foc.first_order_category_english,
        COUNT(*) AS category_customer_count,
        SUM(rl.reordered_180d) AS category_reorder_count,
        (SUM(rl.reordered_180d)::float / COUNT(*)) AS category_reorder_rate
    FROM first_order_category foc
    JOIN reorder_label rl
        ON foc.customer_unique_id = rl.customer_unique_id
       AND foc.first_order_id     = rl.first_order_id
    GROUP BY foc.first_order_category_english
),

/****************************************************
CTE: product_features
WHAT: Attach first-order category and its historical 180-day
      reorder rate to each customer
WHY: Gives the model both the category identity and how
     reorder-heavy that category is on average
GRAIN: Unique customer-level (one row per customer / first order)
*****************************************************/
first_order_product_features AS (
    SELECT
        foc.customer_unique_id,
        foc.first_order_id,
        foc.first_order_category_english,
        crr.category_reorder_rate
    FROM first_order_category foc
    LEFT JOIN category_reorder_rate crr
        ON foc.first_order_category_english = crr.first_order_category_english
),

/****************************************************
CTE: state_base
WHAT: Attach each spine customer to their state
WHY: Foundation for income + state-level reorder rate
GRAIN: Unique customer-level (one row per customer / first order)
*****************************************************/
state_base AS (
    SELECT
		s.customer_id,
        s.customer_unique_id,
        s.first_order_id,
        c.customer_state
    FROM spine s
    LEFT JOIN olist.customers c
        ON s.customer_id = c.customer_id
),

/****************************************************
CTE: state_reorder_rate
WHAT: Compute 180-day reorder rate for each state
WHY: Encodes how reorder-prone each state is overall
GRAIN: State-level (one row per customer_state)
*****************************************************/
state_reorder_rate AS (
    SELECT
        sb.customer_state,
        COUNT(*) AS state_customer_count,
        SUM(rl.reordered_180d) AS state_reorder_count,
        (SUM(rl.reordered_180d)::float / COUNT(*)) AS state_reorder_rate
    FROM state_base sb
    JOIN reorder_label rl
        ON sb.customer_unique_id = rl.customer_unique_id
       AND sb.first_order_id     = rl.first_order_id
    GROUP BY sb.customer_state
),

/****************************************************
CTE: first_order_state_features
WHAT: Attach customer state, state median income, and
      state-level 180d reorder rate to each customer
WHY: Capture both local economic context and state-
     level reorder propensity
GRAIN: Unique customer-level (one row per customer / first order)
*****************************************************/
first_order_state_features AS (
    SELECT
        sb.customer_unique_id,
        sb.first_order_id,
        sb.customer_state,
        smi.median_monthly_income_2017 AS state_median_monthly_income,
        srr.state_reorder_rate
    FROM state_base sb
    LEFT JOIN olist.state_median_income smi
        ON sb.customer_state = smi.state_code
    LEFT JOIN state_reorder_rate srr
        ON sb.customer_state = srr.customer_state)

/***************************************************
FINAL SELECT: Customer-level ABT
WHAT: One row per customer with reorder label and first_order features
WHY: Modeling-ready ABT for reorders within 180 days of first delivered order
GRAIN: Unique customer-level (one row per unique_customer_id)
**************************************************/
SELECT
 rl.customer_unique_id, rl.first_order_id, rl.first_order_timestamp,
 rl.reordered_180d,
 fd.days_to_deliver, fd.actual_vs_estimated_delivery_days,
 fi.first_order_item_count, fi.first_order_price, fi.freight_price_ratio,
 fr.first_order_review_score, fr.review_comment_flag,
 fr.review_comment_length, fr.review_response_delay_days,
 fp.primary_payment_type, fp.count_payment_installments,
 fp.count_payment_sequential, fp.used_multiple_payment_types,
 prod.first_order_category_english AS first_order_category, 
 prod.category_reorder_rate,
 fs.customer_state, fs.state_median_monthly_income,
 fs.state_reorder_rate
FROM reorder_label rl
LEFT JOIN first_order_delivery_features fd
	ON rl.first_order_id = fd.first_order_id
LEFT JOIN first_order_items_features fi
	ON rl.first_order_id = fi.first_order_id
LEFT JOIN first_order_reviews_features fr
	ON rl.first_order_id = fr.first_order_id
LEFT JOIN first_order_payments_features fp
	ON rl.first_order_id = fp.first_order_id   
LEFT JOIN first_order_product_features prod
	ON rl.first_order_id = prod.first_order_id
LEFT JOIN first_order_state_features fs
	ON rl.first_order_id = fs.first_order_id
ORDER BY customer_unique_id;

