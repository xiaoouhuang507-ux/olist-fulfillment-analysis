"""从原始 ZIP 导入 8 张核心表。用于本地 SQL 复现。"""
from __future__ import annotations

import csv
import io
import zipfile
from datetime import datetime
from decimal import Decimal
from pathlib import Path


TABLES = [
    ("customers", "olist_customers_dataset.csv", 99441),
    ("products", "olist_products_dataset.csv", 32951),
    ("sellers", "olist_sellers_dataset.csv", 3095),
    ("orders", "olist_orders_dataset.csv", 99441),
    ("order_items", "olist_order_items_dataset.csv", 112650),
    ("order_payments", "olist_order_payments_dataset.csv", 103886),
    ("order_reviews", "olist_order_reviews_dataset.csv", 99224),
    ("category_translation", "product_category_name_translation.csv", 71),
]
INT_COLUMNS = {
    "product_name_lenght", "product_description_lenght", "product_photos_qty",
    "product_weight_g", "product_length_cm", "product_height_cm", "product_width_cm",
    "order_item_id", "payment_sequential", "payment_installments", "review_score",
}
MONEY_COLUMNS = {"price", "freight_value", "payment_value"}
DATE_COLUMNS = {
    "order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date",
    "order_delivered_customer_date", "order_estimated_delivery_date",
    "shipping_limit_date", "review_creation_date", "review_answer_timestamp",
}


def convert_value(column, value):
    if value == "":
        return None
    if column in INT_COLUMNS:
        return int(value)
    if column in MONEY_COLUMNS:
        return Decimal(value)
    if column in DATE_COLUMNS:
        return datetime.fromisoformat(value)
    return value


def read_sql_statements(path):
    """仅用于本项目无存储过程的静态 SQL 文件，不用于执行外部输入。"""
    content = Path(path).read_text(encoding="utf-8-sig")
    lines = [line for line in content.splitlines() if not line.lstrip().startswith("--")]
    return [part.strip() for part in "\n".join(lines).split(";") if part.strip()]


def execute_sql_file(connection, path):
    with connection.cursor() as cursor:
        for statement in read_sql_statements(path):
            cursor.execute(statement)


def import_archive(connection, archive_path, batch_size=1000):
    """仅允许空表导入。8 张表的数据在一个事务内提交，失败则回滚数据。"""
    archive_path = Path(archive_path)
    if not archive_path.is_file():
        raise FileNotFoundError(f"没有找到数据包：{archive_path}")
    with zipfile.ZipFile(archive_path) as archive:
        missing = [filename for _, filename, _ in TABLES if filename not in archive.namelist()]
        if missing:
            raise ValueError(f"压缩包缺少文件：{missing}")

        # 不删除数据，也不使用 INSERT IGNORE 掩盖重复导入。
        existing = []
        with connection.cursor() as cursor:
            for table, _, _ in TABLES:
                cursor.execute(f"SELECT COUNT(*) FROM `{table}`")
                count = cursor.fetchone()[0]
                if count:
                    existing.append((table, count))
        if existing:
            raise RuntimeError(
                f"检测到已有数据，已停止导入：{existing}。"
                "若已成功导入，请跳过本单元格，继续创建视图和质量检查。"
                "若来源不明或行数不符，请先检查，不要直接清空数据库。"
            )

        report = []
        connection.begin()
        try:
            with connection.cursor() as cursor:
                for table, filename, expected_count in TABLES:
                    with archive.open(filename) as source:
                        reader = csv.DictReader(io.TextIOWrapper(source, encoding="utf-8-sig", newline=""))
                        columns = reader.fieldnames
                        cursor.execute(f"SHOW COLUMNS FROM {chr(96)}{table}{chr(96)}")
                        allowed_columns = {row[0] for row in cursor.fetchall() if "auto_increment" not in row[5]}
                        if not columns or set(columns) != allowed_columns or len(columns) != len(allowed_columns):
                            raise ValueError(f"{filename} 的 CSV 表头与 schema 不一致")
                        column_sql = ", ".join(f"`{col}`" for col in columns)
                        placeholders = ", ".join(["%s"] * len(columns))
                        statement = f"INSERT INTO `{table}` ({column_sql}) VALUES ({placeholders})"
                        batch = []
                        count = 0
                        for row in reader:
                            batch.append(tuple(convert_value(col, row[col]) for col in columns))
                            if len(batch) >= batch_size:
                                cursor.executemany(statement, batch)
                                count += len(batch)
                                batch = []
                        if batch:
                            cursor.executemany(statement, batch)
                            count += len(batch)
                    if count != expected_count:
                        raise ValueError(f"{table} 的数据包行数异常：{count}，预期 {expected_count}")
                    cursor.execute(f"SELECT COUNT(*) FROM `{table}`")
                    imported_count = cursor.fetchone()[0]
                    if imported_count != count:
                        raise ValueError(f"{table} 入库行数不一致：{imported_count} / {count}")
                    report.append({"table": table, "rows": count})
                    print(f"{table}: {count:,} 行已写入事务，尚未统一提交")
            connection.commit()
        except Exception:
            connection.rollback()
            print("导入失败，本轮 8 张表的数据写入已回滚。已创建的空表会保留。")
            raise
        print("8 张核心表已全部提交。地理定位表留到地图分析阶段再导入。")
        return report
