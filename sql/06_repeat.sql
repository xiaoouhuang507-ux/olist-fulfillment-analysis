USE olist_ai_pm;

-- C1：按数据内首购月份计算 30 天跨日复购。
WITH purchase_days AS (
    SELECT
        customer_unique_id,
        DATE(order_purchase_timestamp) AS purchase_day
    FROM v_order_base
    WHERE order_status = 'delivered'
      AND product_amount IS NOT NULL
      AND order_purchase_timestamp < '2018-08-01'
    GROUP BY customer_unique_id, DATE(order_purchase_timestamp)
),
sequenced AS (
    SELECT
        customer_unique_id,
        purchase_day,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY purchase_day
        ) AS rn,
        LEAD(purchase_day) OVER (
            PARTITION BY customer_unique_id
            ORDER BY purchase_day
        ) AS next_purchase_day
    FROM purchase_days
),
first_purchases AS (
    SELECT customer_unique_id, purchase_day, next_purchase_day
    FROM sequenced
    WHERE rn = 1
      AND purchase_day >= '2017-01-01'
      AND purchase_day < '2018-07-01'
      AND DATE_ADD(purchase_day, INTERVAL 30 DAY) < '2018-08-01'
)
SELECT
    DATE_FORMAT(purchase_day, '%Y-%m') AS first_purchase_month,
    COUNT(*) AS eligible_buyers,
    SUM(
        CASE
            WHEN DATEDIFF(next_purchase_day, purchase_day)
                 BETWEEN 1 AND 30
            THEN 1 ELSE 0
        END
    ) AS repeat_buyers_30d,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN DATEDIFF(next_purchase_day, purchase_day)
                     BETWEEN 1 AND 30
                THEN 1 ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS repeat_rate_30d_pct
FROM first_purchases
GROUP BY DATE_FORMAT(purchase_day, '%Y-%m')
ORDER BY first_purchase_month;

-- C2：固定买家队列，比较 30/60/90 天累计跨日复购。
WITH purchase_days AS (
    SELECT
        customer_unique_id,
        DATE(order_purchase_timestamp) AS purchase_day
    FROM v_order_base
    WHERE order_status = 'delivered'
      AND product_amount IS NOT NULL
      AND order_purchase_timestamp < '2018-08-01'
    GROUP BY customer_unique_id, DATE(order_purchase_timestamp)
),
sequenced AS (
    SELECT
        customer_unique_id,
        purchase_day,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id ORDER BY purchase_day
        ) AS rn,
        LEAD(purchase_day) OVER (
            PARTITION BY customer_unique_id ORDER BY purchase_day
        ) AS next_purchase_day
    FROM purchase_days
),
first_purchases AS (
    SELECT customer_unique_id, purchase_day, next_purchase_day
    FROM sequenced
    WHERE rn = 1
      AND purchase_day >= '2017-01-01'
      AND purchase_day < '2018-05-01'
      AND DATE_ADD(purchase_day, INTERVAL 90 DAY) < '2018-08-01'
),
observation_windows AS (
    SELECT 30 AS window_days
    UNION ALL SELECT 60
    UNION ALL SELECT 90
)
SELECT
    w.window_days,
    COUNT(*) AS eligible_buyers,
    SUM(
        CASE
            WHEN DATEDIFF(f.next_purchase_day, f.purchase_day)
                 BETWEEN 1 AND w.window_days
            THEN 1 ELSE 0
        END
    ) AS repeat_buyers,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN DATEDIFF(f.next_purchase_day, f.purchase_day)
                     BETWEEN 1 AND w.window_days
                THEN 1 ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS repeat_rate_pct
FROM first_purchases f
CROSS JOIN observation_windows w
GROUP BY w.window_days
ORDER BY w.window_days;
