CREATE OR REPLACE VIEW olist.dashboard_customer_first_order AS
SELECT
 customer_unique_id,
 reordered_180d,
 first_order_timestamp,
 first_order_category,
 first_order_price,
 first_order_item_count,
 customer_state,
 first_order_review_score,
 actual_vs_estimated_delivery_days
FROM olist.abt_customer_reorder_180d;

SELECT * FROM olist.dashboard_customer_first_order;