"""导入 Olist 数据并运行仓库中的汇总 SQL。"""
import argparse
from getpass import getpass
from pathlib import Path

import pymysql

from import_mysql import execute_sql_file, import_archive, read_sql_statements


ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / "sql"
STAGES = {
    "quality": "03_quality_checks.sql",
    "baseline": "04_first_analysis.sql",
    "fulfillment": "05_fulfillment.sql",
    "repeat": "06_repeat.sql",
    "reviews": "07_review_coverage.sql",
}


def iter_results(connection, path):
    with connection.cursor() as cursor:
        for statement in read_sql_statements(path):
            cursor.execute(statement)
            if cursor.description is not None:
                yield [field[0] for field in cursor.description], cursor.fetchall()


def init_database(connection, archive):
    execute_sql_file(connection, SQL / "01_schema.sql")
    import_archive(connection, archive)
    execute_sql_file(connection, SQL / "02_order_view.sql")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["init", "run"])
    parser.add_argument("--user", default="root")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3306)
    parser.add_argument("--archive", type=Path, default=ROOT / "data" / "archive.zip")
    parser.add_argument("--stage", choices=["all", *STAGES], default="all")
    args = parser.parse_args()
    if args.command == "init" and not args.archive.is_file():
        parser.error(f"找不到 ZIP：{args.archive}")
    password = getpass("MySQL 密码（输入不可见）：")
    with pymysql.connect(
        host=args.host,
        port=args.port,
        user=args.user,
        password=password,
        charset="utf8mb4",
    ) as connection:
        if args.command == "init":
            init_database(connection, args.archive)
            return
        stages = STAGES if args.stage == "all" else {args.stage: STAGES[args.stage]}
        for stage, filename in stages.items():
            for index, (columns, rows) in enumerate(iter_results(connection, SQL / filename), 1):
                print(f"\n[{stage} {index}]")
                print("\t".join(columns))
                for row in rows:
                    print("\t".join("NULL" if value is None else str(value) for value in row))


if __name__ == "__main__":
    main()
