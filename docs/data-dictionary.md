# 数据字典与口径记录

来源：用户提供的 `archive.zip`。以下行数和关系已对该包实际检查，不是从网上照搬的预期值。

| 原始 CSV / 数据库表 | 行数 | 一行代表什么 | 主键 / 关联 |
|---|---:|---|---|
| olist_customers_dataset / customers | 99,441 | 一条订单客户记录，同一实际买家可有多条 | `customer_id` 唯一；跨订单买家用 `customer_unique_id` |
| olist_orders_dataset / orders | 99,441 | 一笔订单 | `order_id` 唯一；`customer_id` 关联 customers |
| olist_order_items_dataset / order_items | 112,650 | 订单中的一个商品明细行 | `(order_id, order_item_id)` 唯一；关联订单、商品、卖家 |
| olist_order_payments_dataset / order_payments | 103,886 | 一笔订单的一条支付记录 | `(order_id, payment_sequential)` 唯一 |
| olist_order_reviews_dataset / order_reviews | 99,224 | 一条订单评价记录 | 本包 `(review_id, order_id)` 唯一；入库另设 `review_row_id` |
| olist_products_dataset / products | 32,951 | 一种商品 | `product_id` 唯一；品类有缺失 |
| olist_sellers_dataset / sellers | 3,095 | 一个卖家 | `seller_id` 唯一 |
| product_category_name_translation / category_translation | 71 | 一项品类葡语到英语的映射 | `product_category_name` 唯一 |
| olist_geolocation_dataset / 暂不导入 | 1,000,163 | 一个邮编前缀对应的位置采样记录 | 邮编前缀不唯一，不可直接关联后求和 |

## 核心字段

- `order_status`：订单状态。`delivered` 是已送达，`canceled` 是已取消。原始订单总数与成交口径订单数不同。
- `order_purchase_timestamp`：下单时间，月度趋势按此字段归属月份。
- `order_delivered_customer_date`：实际送达时间。
- `order_estimated_delivery_date`：预计送达日期。按自然日比较，避免把当天送达误判为延迟。
- `price`：商品明细价格。与运费、支付金额分别保存，不能相加当作收入。
- `freight_value`：该商品明细对应的运费。
- `payment_value`：一条支付记录金额。一个订单可分多次或多种方式支付。
- `review_score`：1～5 分。评论文本为空时仍可能有有效评分。
- `review_answer_timestamp`：评价答复时间。订单有多条评价时，按该字段、创建时间、入库行号依次倒序取一条。
- `product_category_name`：葡语品类名。映射时使用 LEFT JOIN，缺失/未映射值归入未知，不删除订单。
- `product_name_lenght`、`product_description_lenght`：原始 CSV 的拼写如此，入库先保持一致。

所有邮编前缀按字符串保存，避免丢失前导零。金额使用 DECIMAL，空值写入 SQL NULL，原始日期不自行假定时区或换算时区。

## 已发现的缺失和重复

- 客户表有 96,096 个不同的 `customer_unique_id`，不能用客户表行数当买家数。
- 8 笔已送达订单缺少实际签收时间。这些订单可以进入成交统计，但不进入延迟率分母。
- 610 个商品缺少品类、名称长度、描述长度和图片数量；2 个商品缺少重量或尺寸。
- 58,274 条评价没有正文，87,658 条没有标题。保留其评分，不凭空生成评论文本。
- 评价 `review_id` 单列重复多出 814 行，但整行完全重复数为 0，组合键 `(review_id, order_id)` 重复数为 0。
- 订单→客户、明细→订单/商品/卖家、支付→订单、评价→订单的引用缺失数均为 0。

## 订单分析视图 v_order_base

视图固定为一行一笔订单，预期 99,441 行。主要字段：

| 字段 | 含义 |
|---|---|
| item_count / product_count / seller_count | 明细行数 / 不同商品数 / 不同卖家数 |
| product_amount / freight_amount | 商品明细价格合计 / 运费合计 |
| payment_count / payment_amount | 支付记录数 / 支付金额合计 |
| review_count / review_score | 原始评价条数 / 最新评价的评分 |
| is_late | 日期有效的已送达订单，延迟为 1，准时为 0，其他为 NULL |
| delivery_days | 已送达且时间有效的订单，从下单至实际签收的天数，可有小数 |

视图保留所有订单状态。每项指标的状态和时间筛选在分析 SQL 中明确指定，避免隐藏筛选口径。

## 数据能力边界

数据包含历史订单、支付、履约和评分记录，不包含完整曝光、点击、加购、客服处置、退款金额和成本数据。因此不能据此计算真实点击转化率、完整退款率、净利润，也不能验证某个产品功能已经产生提升。

首尾月份订单量明显偏少：2016-09 仅 4 笔，2018-09 仅 16 笔，2018-10 仅 4 笔。后续做固定周期复购时，要单独设计完整观察窗口，不能拿最后一笔订单日期当作完整采集截止日期。
