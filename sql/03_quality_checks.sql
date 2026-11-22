USE olist_ai_pm;

-- Q1：实际行数应与压缩包完全一致，8 行 difference 均应为 0。
SELECT 'customers' AS table_name, COUNT(*) AS actual_rows, 99441 AS expected_rows,
       CAST(COUNT(*) AS SIGNED) - 99441 AS difference FROM customers
UNION ALL SELECT 'products', COUNT(*), 32951, CAST(COUNT(*) AS SIGNED) - 32951 FROM products
UNION ALL SELECT 'sellers', COUNT(*), 3095, CAST(COUNT(*) AS SIGNED) - 3095 FROM sellers
UNION ALL SELECT 'orders', COUNT(*), 99441, CAST(COUNT(*) AS SIGNED) - 99441 FROM orders
UNION ALL SELECT 'order_items', COUNT(*), 112650, CAST(COUNT(*) AS SIGNED) - 112650 FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*), 103886, CAST(COUNT(*) AS SIGNED) - 103886 FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*), 99224, CAST(COUNT(*) AS SIGNED) - 99224 FROM order_reviews
UNION ALL SELECT 'category_translation', COUNT(*), 71, CAST(COUNT(*) AS SIGNED) - 71 FROM category_translation;

-- Q2：订单视图既不丢订单，也不放大订单数。
SELECT COUNT(*) AS view_rows,
       COUNT(DISTINCT order_id) AS distinct_orders,
       (SELECT COUNT(*) FROM orders) AS raw_orders
FROM v_order_base;

-- Q3：视图汇总与各原表金额一致，三项差额均应为 0.00。
SELECT (SELECT SUM(product_amount) FROM v_order_base)
         - (SELECT SUM(price) FROM order_items) AS product_amount_difference,
       (SELECT SUM(freight_amount) FROM v_order_base)
         - (SELECT SUM(freight_value) FROM order_items) AS freight_amount_difference,
       (SELECT SUM(payment_amount) FROM v_order_base)
         - (SELECT SUM(payment_value) FROM order_payments) AS payment_amount_difference;

-- Q4：缺失不一定是错误。未送达订单没有签收日期是合理的。
SELECT SUM(CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders,
       SUM(CASE WHEN order_status = 'delivered'
                     AND order_delivered_customer_date IS NULL THEN 1 ELSE 0 END)
         AS delivered_missing_actual_date,
       SUM(CASE WHEN item_count IS NULL THEN 1 ELSE 0 END) AS orders_without_items,
       SUM(CASE WHEN payment_count IS NULL THEN 1 ELSE 0 END) AS orders_without_payments,
       SUM(CASE WHEN review_count IS NULL THEN 1 ELSE 0 END) AS orders_without_reviews,
       SUM(CASE WHEN order_delivered_customer_date < order_purchase_timestamp
                THEN 1 ELSE 0 END) AS delivery_before_purchase
FROM v_order_base;

-- Q5：同一 review_id 可关联不同订单，不可直接按 review_id 去重。
SELECT COUNT(*) AS review_rows,
       COUNT(DISTINCT review_id) AS distinct_review_ids,
       COUNT(*) - COUNT(DISTINCT review_id) AS repeated_id_extra_rows,
       SUM(CASE WHEN review_score NOT BETWEEN 1 AND 5 THEN 1 ELSE 0 END) AS invalid_scores
FROM order_reviews;

-- Q6：一对多关系的规模，用来解释为什么要先聚合。
SELECT SUM(CASE WHEN item_count > 1 THEN 1 ELSE 0 END) AS multi_item_orders,
       SUM(CASE WHEN payment_count > 1 THEN 1 ELSE 0 END) AS multi_payment_orders,
       SUM(CASE WHEN review_count > 1 THEN 1 ELSE 0 END) AS multi_review_orders
FROM v_order_base;

-- Q7：查看数据覆盖范围，注意首尾月份样本量明显偏少。
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS purchase_month,
       COUNT(*) AS orders
FROM orders
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY purchase_month;
