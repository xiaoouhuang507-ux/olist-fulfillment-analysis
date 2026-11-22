-- MySQL 8.0。仅创建新对象，不删除已有数据。
CREATE DATABASE IF NOT EXISTS olist_ai_pm
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE olist_ai_pm;

CREATE TABLE IF NOT EXISTS customers (
  customer_id CHAR(32) NOT NULL PRIMARY KEY,
  customer_unique_id CHAR(32) NOT NULL,
  customer_zip_code_prefix VARCHAR(5) NOT NULL,
  customer_city VARCHAR(128) NOT NULL,
  customer_state CHAR(2) NOT NULL,
  INDEX idx_customer_unique (customer_unique_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS products (
  product_id CHAR(32) NOT NULL PRIMARY KEY,
  product_category_name VARCHAR(128) NULL,
  product_name_lenght INT NULL,
  product_description_lenght INT NULL,
  product_photos_qty INT NULL,
  product_weight_g INT NULL,
  product_length_cm INT NULL,
  product_height_cm INT NULL,
  product_width_cm INT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sellers (
  seller_id CHAR(32) NOT NULL PRIMARY KEY,
  seller_zip_code_prefix VARCHAR(5) NOT NULL,
  seller_city VARCHAR(128) NOT NULL,
  seller_state CHAR(2) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orders (
  order_id CHAR(32) NOT NULL PRIMARY KEY,
  customer_id CHAR(32) NOT NULL,
  order_status VARCHAR(32) NOT NULL,
  order_purchase_timestamp DATETIME NOT NULL,
  order_approved_at DATETIME NULL,
  order_delivered_carrier_date DATETIME NULL,
  order_delivered_customer_date DATETIME NULL,
  order_estimated_delivery_date DATETIME NOT NULL,
  INDEX idx_purchase_date (order_purchase_timestamp),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
  order_id CHAR(32) NOT NULL,
  order_item_id INT NOT NULL,
  product_id CHAR(32) NOT NULL,
  seller_id CHAR(32) NOT NULL,
  shipping_limit_date DATETIME NOT NULL,
  price DECIMAL(12,2) NOT NULL,
  freight_value DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (order_id, order_item_id),
  CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
  CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(product_id),
  CONSTRAINT fk_items_seller FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_payments (
  order_id CHAR(32) NOT NULL,
  payment_sequential INT NOT NULL,
  payment_type VARCHAR(32) NOT NULL,
  payment_installments INT NOT NULL,
  payment_value DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (order_id, payment_sequential),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_reviews (
  review_row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  review_id CHAR(32) NOT NULL,
  order_id CHAR(32) NOT NULL,
  review_score TINYINT NOT NULL,
  review_comment_title TEXT NULL,
  review_comment_message TEXT NULL,
  review_creation_date DATETIME NOT NULL,
  review_answer_timestamp DATETIME NOT NULL,
  UNIQUE KEY uq_review_order (review_id, order_id),
  INDEX idx_review_order (order_id),
  CONSTRAINT fk_reviews_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS category_translation (
  product_category_name VARCHAR(128) NOT NULL PRIMARY KEY,
  product_category_name_english VARCHAR(128) NOT NULL
) ENGINE=InnoDB;
