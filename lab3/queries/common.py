from datetime import datetime, timedelta
from sqlalchemy import select, func, distinct, text
from api.engine import DBConn
from models import Author, Magazine, Store, Department, Stock, Customer, Sale


def run_all_queries():
    with DBConn.get_session() as session:
        print("\n" + "=" * 80)
        print("1. Які журнали було куплено покупцем з customer_id = 1?")
        print("=" * 80)
        stmt1 = (
            select(Magazine.title, Magazine.series, Magazine.isbn, Sale.sale_date)
            .join(Sale, Magazine.magazine_id == Sale.magazine_id)
            .where(Sale.customer_id == 1)
            .order_by(Sale.sale_date)
        )
        results1 = session.execute(stmt1).all()
        for row in results1:
            print(f"Журнал: {row.title:<22} | Серія: {row.series:<12} | ISBN: {row.isbn} | Дата: {row.sale_date}")

        print("\n" + "=" * 80)
        print("2. Як називається журнал із заданим ISBN ('978-4-0631-0001-7')?")
        print("=" * 80)
        stmt2 = select(Magazine.title).where(Magazine.isbn == "978-4-0631-0001-7")
        title = session.scalar(stmt2)
        print(f"Назва журналу: {title}")

        print("\n" + "=" * 80)
        print("3. Який ISBN у журналу із назвою 'Akira'?")
        print("=" * 80)
        stmt3 = select(Magazine.title, Magazine.isbn).where(Magazine.title == "Akira")
        result3 = session.execute(stmt3).first()
        if result3:
            print(f"Назва: {result3.title} | ISBN: {result3.isbn}")

        print("\n" + "=" * 80)
        print("4. Коли журнал 'Akira' (magazine_id = 3) купили?")
        print("=" * 80)
        stmt4 = (
            select(
                Magazine.title,
                Sale.sale_date,
                Customer.full_name.label("buyer"),
                Store.name.label("store"),
            )
            .join(Sale, Sale.magazine_id == Magazine.magazine_id)
            .join(Customer, Customer.customer_id == Sale.customer_id)
            .join(Department, Department.department_id == Sale.department_id)
            .join(Store, Store.store_id == Department.store_id)
            .where(Magazine.magazine_id == 3)
            .order_by(Sale.sale_date)
        )
        results4 = session.execute(stmt4).all()
        for row in results4:
            print(f"Дата: {row.sale_date} | Покупець: {row.buyer:<28} | Магазин: {row.store}")

        print("\n" + "=" * 80)
        print("5. Хто з покупців купив журнал понад місяць тому?")
        print("=" * 80)
        month_ago = datetime.now().date() - timedelta(days=30)
        stmt5 = (
            select(Customer.customer_id, Customer.full_name, Customer.email)
            .join(Sale, Customer.customer_id == Sale.customer_id)
            .where(Sale.sale_date < month_ago)
            .distinct()
            .order_by(Customer.customer_id)
        )
        results5 = session.execute(stmt5).all()
        for row in results5:
            print(f"ID: {row.customer_id} | Покупець: {row.full_name:<28} | Email: {row.email}")

        print("\n" + "=" * 80)
        print("6. Покупці, які купували журнали із сум. залишком від 1 до 5 шт. (HAVING SUM(quantity) BETWEEN 1 AND 5)")
        print("=" * 80)
        subq6 = (
            select(Stock.magazine_id)
            .group_by(Stock.magazine_id)
            .having(func.sum(Stock.quantity).between(1, 5))
        )
        stmt6 = (
            select(Customer.full_name, Customer.email)
            .join(Sale, Customer.customer_id == Sale.customer_id)
            .where(Sale.magazine_id.in_(subq6))
            .distinct()
        )
        results6 = session.execute(stmt6).all()
        for row in results6:
            print(f"Покупець: {row.full_name:<28} | Email: {row.email}")

        print("\n" + "=" * 80)
        print("7. Яка кількість покупців користується магазином 'Комікс-Центр'?")
        print("=" * 80)
        stmt7 = (
            select(
                Store.name,
                func.count(distinct(Sale.customer_id)).label("customers_count"),
            )
            .join(Department, Department.store_id == Store.store_id)
            .outerjoin(Sale, Sale.department_id == Department.department_id)
            .where(Store.name == "Комікс-Центр")
            .group_by(Store.name)
        )
        result7 = session.execute(stmt7).first()
        if result7:
            print(f"Магазин: {result7.name} | Кількість покупців: {result7.customers_count}")

        print("\n" + "=" * 80)
        print("8. Скільки покупців молодших за 20 років?")
        print("=" * 80)
        stmt8 = select(func.count()).where(
            func.age(func.current_date(), Customer.birth_date) < text("INTERVAL '20 years'")
        )
        under_20 = session.scalar(stmt8)
        print(f"Кількість покупців молодше 20 років: {under_20}")
        print("=" * 80 + "\n")