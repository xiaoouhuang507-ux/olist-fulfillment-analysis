USE olist_ai_pm;

-- D1：目标品类各组评论正文覆盖。
WITH single_category_orders AS (
    SELECT
        i.order_id,
        MAX(p.product_category_name) AS category_name
    FROM order_items i
    LEFT JOIN products p ON p.product_id = i.product_id
    GROUP BY i.order_id
    HAVING COUNT(p.product_category_name) = COUNT(*)
       AND COUNT(DISTINCT p.product_category_name) = 1
),
comment_pool AS (
    SELECT
        v.order_id,
        CASE
            WHEN v.review_score IS NULL THEN 'unrated'
            WHEN v.is_late = 1 AND v.review_score <= 2
                THEN 'late_low'
            WHEN v.is_late = 1 THEN 'late_non_low'
            WHEN v.review_score <= 2 THEN 'on_time_low'
            ELSE 'on_time_non_low'
        END AS review_group,
        CASE
            WHEN v.review_comment_message IS NOT NULL
             AND CHAR_LENGTH(TRIM(v.review_comment_message)) > 0
            THEN 1 ELSE 0
        END AS has_text
    FROM v_order_base v
    JOIN single_category_orders c ON c.order_id = v.order_id
    JOIN category_translation t
        ON t.product_category_name = c.category_name
    WHERE v.order_status = 'delivered'
      AND v.is_late IS NOT NULL
      AND v.customer_state = 'RJ'
      AND t.product_category_name_english = 'bed_bath_table'
      AND v.order_purchase_timestamp >= '2017-01-01'
      AND v.order_purchase_timestamp < '2018-09-01'
)
SELECT
    review_group,
    COUNT(*) AS orders,
    SUM(has_text) AS orders_with_text,
    ROUND(
        100.0 * SUM(has_text) / COUNT(*),
        2
    ) AS text_coverage_pct
FROM comment_pool
GROUP BY review_group
ORDER BY review_group;

-- D2：复现分层固定抽样规模，查询仅输出每组条数。
WITH single_category_orders AS (
    SELECT i.order_id, MAX(p.product_category_name) AS category_name
    FROM order_items i
    LEFT JOIN products p ON p.product_id = i.product_id
    GROUP BY i.order_id
    HAVING COUNT(p.product_category_name) = COUNT(*)
       AND COUNT(DISTINCT p.product_category_name) = 1
),
comment_pool AS (
    SELECT
        v.order_id, v.order_purchase_timestamp,
        v.is_late, v.review_score, v.review_comment_message,
        CONCAT(
            CASE WHEN v.is_late = 1 THEN 'late' ELSE 'on_time' END,
            '_',
            CASE WHEN v.review_score <= 2 THEN 'low' ELSE 'non_low' END
        ) AS review_group
    FROM v_order_base v
    JOIN single_category_orders c ON c.order_id = v.order_id
    JOIN category_translation t ON t.product_category_name = c.category_name
    WHERE v.order_status = 'delivered'
      AND v.is_late IS NOT NULL
      AND v.customer_state = 'RJ'
      AND t.product_category_name_english = 'bed_bath_table'
      AND v.order_purchase_timestamp >= '2017-01-01'
      AND v.order_purchase_timestamp < '2018-09-01'
      AND v.review_score BETWEEN 1 AND 5
      AND CHAR_LENGTH(TRIM(v.review_comment_message)) > 0
),
ranked_pool AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY review_group
            ORDER BY MD5(order_id), order_id
        ) AS sample_rn
    FROM comment_pool
)
SELECT review_group, COUNT(*) AS sample_count
FROM ranked_pool
WHERE sample_rn <= 10
GROUP BY review_group
ORDER BY review_group;
