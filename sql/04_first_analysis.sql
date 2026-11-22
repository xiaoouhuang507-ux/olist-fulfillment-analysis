USE olist_ai_pm;

-- A1：订单状态分布。回答哪些订单可以进入成交和履约指标。
SELECT order_status, COUNT(*) AS order_count,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders), 2) AS share_pct
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- A2：2018 年上半年，按下单月份统计商品成交额与客单价（筛选练习）。
-- 该窗口首尾覆盖较完整，但并不意味着数据包含全部真实交易。
-- 商品成交额仅包含已送达且有商品明细的订单，不含运费，币种 BRL。
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS purchase_month,
       COUNT(*) AS delivered_orders_with_items,
       ROUND(SUM(product_amount), 2) AS delivered_product_amount_brl,
       ROUND(SUM(product_amount) / COUNT(*), 2) AS avg_order_value_brl
FROM v_order_base
WHERE order_status = 'delivered'
  AND product_amount IS NOT NULL
    AND order_purchase_timestamp >= '2018-01-01'
    AND order_purchase_timestamp < '2018-07-01'
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY purchase_month;

-- A3：圣保罗州（SP）在主窗口内的延迟率。分母仅包含日期有效的已送达订单。
SELECT COUNT(*) AS delivered_orders,
       COUNT(is_late) AS orders_with_valid_delivery_dates,
       SUM(is_late) AS late_orders,
       ROUND(100.0 * SUM(is_late) / NULLIF(COUNT(is_late), 0), 2) AS late_rate_pct,
       ROUND(AVG(delivery_days), 2) AS avg_delivery_days
FROM v_order_base
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
  AND customer_state = 'SP';

-- A4：延迟与低评分的关联，每笔订单只取最新评价。低评分定义为 1～2 分。
-- 仅代表有评价订单中的统计关联，不能证明延迟导致低评分。
SELECT CASE WHEN is_late = 1 THEN 'late' ELSE 'on_time' END AS delivery_group,
       COUNT(*) AS eligible_orders,
       COUNT(review_score) AS reviewed_orders,
       ROUND(100.0 * COUNT(review_score) / COUNT(*), 2) AS review_coverage_pct,
       ROUND(AVG(review_score), 2) AS avg_review_score,
       ROUND(100.0 * SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(review_score), 0), 2) AS low_score_rate_pct
FROM v_order_base
WHERE order_status = 'delivered'
  AND is_late IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
GROUP BY is_late;

-- A5：全样本窗口内，购买至少两笔已送达订单的买家占比。
-- 这是描述性复购买家占比，不是 30/60/90 天留存率。
WITH buyer_orders AS (
  SELECT customer_unique_id, COUNT(*) AS delivered_orders
  FROM v_order_base
  WHERE order_status = 'delivered' AND product_amount IS NOT NULL
  GROUP BY customer_unique_id
)
SELECT COUNT(*) AS buyers,
       SUM(CASE WHEN delivered_orders >= 2 THEN 1 ELSE 0 END) AS repeat_buyers,
       ROUND(100.0 * SUM(CASE WHEN delivered_orders >= 2 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0), 2) AS observed_repeat_buyer_pct
FROM buyer_orders;
