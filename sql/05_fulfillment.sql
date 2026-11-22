USE olist_ai_pm;

-- B0：全样本主窗口延迟率。
SELECT COUNT(*) AS delivered_orders,
       COUNT(is_late) AS orders_with_valid_delivery_dates,
       SUM(is_late) AS late_orders,
       ROUND(100.0 * SUM(is_late) / NULLIF(COUNT(is_late), 0), 2) AS late_rate_pct,
       ROUND(AVG(delivery_days), 2) AS avg_delivery_days
FROM v_order_base
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01';

-- B1：州级履约表现，保留至少 100 笔日期有效订单的州。
SELECT
    customer_state,
    COUNT(*) AS delivered_orders,
    COUNT(is_late) AS orders_with_valid_dates,
    SUM(is_late) AS late_orders,
    ROUND(
        100.0 * SUM(is_late) / NULLIF(COUNT(is_late), 0),
        2
    ) AS late_rate_pct,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days
FROM v_order_base
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
GROUP BY customer_state
HAVING COUNT(is_late) >= 100
ORDER BY late_orders DESC;

-- B2：里约热内卢州延迟与低评分的关系。
SELECT
    CASE
        WHEN is_late = 1 THEN 'late'
        ELSE 'on_time'
    END AS delivery_group,
    COUNT(*) AS eligible_orders,
    COUNT(review_score) AS reviewed_orders,
    ROUND(
        100.0 * COUNT(review_score) / COUNT(*),
        2
    ) AS review_coverage_pct,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(
        100.0 * SUM(
            CASE WHEN review_score <= 2 THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(review_score), 0),
        2
    ) AS low_score_rate_pct
FROM v_order_base
WHERE order_status = 'delivered'
  AND is_late IS NOT NULL
  AND customer_state = 'RJ'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
GROUP BY is_late
ORDER BY is_late;

-- B3：按月检查里约热内卢州的关联方向。
SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS purchase_month,
    CASE
        WHEN is_late = 1 THEN 'late'
        ELSE 'on_time'
    END AS delivery_group,
    COUNT(review_score) AS reviewed_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(
        100.0 * SUM(
            CASE WHEN review_score <= 2 THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(review_score), 0),
        2
    ) AS low_score_rate_pct
FROM v_order_base
WHERE order_status = 'delivered'
  AND is_late IS NOT NULL
  AND customer_state = 'RJ'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
GROUP BY
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m'),
    is_late
ORDER BY purchase_month, is_late;

-- B4：品类分层，单一品类与多品类、缺失品类分开。
WITH order_category AS (
    SELECT
        i.order_id,
        CASE
            WHEN COUNT(p.product_category_name) < COUNT(*)
                THEN 'unknown_or_partial'
            WHEN COUNT(DISTINCT p.product_category_name) = 1
                THEN MAX(p.product_category_name)
            ELSE 'mixed_categories'
        END AS category_name
    FROM order_items i
    LEFT JOIN products p
        ON p.product_id = i.product_id
    GROUP BY i.order_id
)
SELECT
    COALESCE(
        t.product_category_name_english,
        oc.category_name,
        'unknown_or_partial'
    ) AS product_category,
    COUNT(*) AS eligible_orders,
    SUM(v.is_late) AS late_orders,
    ROUND(
        100.0 * SUM(v.is_late) / COUNT(*),
        2
    ) AS late_rate_pct,
    COUNT(v.review_score) AS reviewed_orders,
    ROUND(
        100.0 * SUM(
            CASE WHEN v.review_score <= 2 THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(v.review_score), 0),
        2
    ) AS low_score_rate_pct
FROM v_order_base v
LEFT JOIN order_category oc
    ON oc.order_id = v.order_id
LEFT JOIN category_translation t
    ON t.product_category_name = oc.category_name
WHERE v.order_status = 'delivered'
  AND v.is_late IS NOT NULL
  AND v.customer_state = 'RJ'
  AND v.order_purchase_timestamp >= '2017-01-01'
  AND v.order_purchase_timestamp < '2018-09-01'
GROUP BY COALESCE(
    t.product_category_name_english,
    oc.category_name,
    'unknown_or_partial'
)
HAVING COUNT(*) >= 100
ORDER BY late_orders DESC, product_category;
