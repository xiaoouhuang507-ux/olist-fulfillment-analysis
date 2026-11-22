USE olist_ai_pm;

-- 先把各明细表归并到一行一订单，再关联。保留缺失值供质量检查。
CREATE OR REPLACE VIEW v_order_base AS
WITH item_totals AS (
  SELECT order_id,
         COUNT(*) AS item_count,
         COUNT(DISTINCT product_id) AS product_count,
         COUNT(DISTINCT seller_id) AS seller_count,
         SUM(price) AS product_amount,
         SUM(freight_value) AS freight_amount
  FROM order_items
  GROUP BY order_id
), payment_totals AS (
  SELECT order_id,
         COUNT(*) AS payment_count,
         SUM(payment_value) AS payment_amount
  FROM order_payments
  GROUP BY order_id
), ranked_reviews AS (
  SELECT r.*,
         ROW_NUMBER() OVER (
           PARTITION BY order_id
           ORDER BY review_answer_timestamp DESC,
                    review_creation_date DESC, review_row_id DESC
         ) AS rn,
         COUNT(*) OVER (PARTITION BY order_id) AS review_count
  FROM order_reviews r
)
SELECT o.order_id, o.customer_id, c.customer_unique_id,
       c.customer_state, o.order_status,
       o.order_purchase_timestamp,
       o.order_delivered_customer_date,
       o.order_estimated_delivery_date,
       i.item_count, i.product_count, i.seller_count,
       i.product_amount, i.freight_amount,
       p.payment_count, p.payment_amount,
       r.review_count, r.review_score,
       r.review_comment_message,
       CASE
         WHEN o.order_status = 'delivered'
          AND o.order_delivered_customer_date IS NOT NULL
          AND o.order_estimated_delivery_date IS NOT NULL
          AND o.order_delivered_customer_date >= o.order_purchase_timestamp
          AND DATE(o.order_estimated_delivery_date) >= DATE(o.order_purchase_timestamp)
         THEN CASE WHEN DATE(o.order_delivered_customer_date)
                           > DATE(o.order_estimated_delivery_date)
                   THEN 1 ELSE 0 END
         ELSE NULL
       END AS is_late,
       CASE
         WHEN o.order_status = 'delivered'
          AND o.order_delivered_customer_date >= o.order_purchase_timestamp
         THEN TIMESTAMPDIFF(SECOND, o.order_purchase_timestamp,
                            o.order_delivered_customer_date) / 86400.0
         ELSE NULL
       END AS delivery_days
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
LEFT JOIN item_totals i ON i.order_id = o.order_id
LEFT JOIN payment_totals p ON p.order_id = o.order_id
LEFT JOIN ranked_reviews r ON r.order_id = o.order_id AND r.rn = 1;
