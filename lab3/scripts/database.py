from datetime import datetime
from api.engine import DBConn
from models import Author, Magazine, Store, Department, Stock, Customer, Sale


def fill_db():
    with DBConn.get_session() as session:
        try:
            # 1. Створення Авторів (INSERT INTO author)
            authors = [
                Author(full_name="Стен Лі"),           # id 1
                Author(full_name="Стів Дітко"),        # id 2
                Author(full_name="Френк Міллер"),      # id 3
                Author(full_name="Девід Мацукеллі"),   # id 4
                Author(full_name="Кацухіро Отомо"),     # id 5
                Author(full_name="Ніл Гейман"),        # id 6
            ]
            session.add_all(authors)
            session.commit()

            # 2. Створення Журналів (INSERT INTO magazine)
            m1 = Magazine(title="Amazing Spider-Man", series="Spider-Man", publisher="Marvel", year=1963, isbn="978-0-7851-1001-1")
            m2 = Magazine(title="Batman: Year One", series="Batman", publisher="DC Comics", year=1987, isbn="978-1-4012-0752-4")
            m3 = Magazine(title="Akira", series="Akira", publisher="Kodansha", year=1988, isbn="978-4-0631-0001-7")
            m4 = Magazine(title="The Sandman", series="Sandman", publisher="Vertigo", year=1989, isbn="978-1-4012-1001-8")
            m5 = Magazine(title="Fantastic Four", series="Fantastic Four", publisher="Marvel", year=1961, isbn="978-0-7851-1005-5")

            # Зв'язки Magazine <-> Author (INSERT INTO magazine_author)
            m1.authors.extend([authors[0], authors[1]])  # Spider-Man: Стен Лі, Стів Дітко
            m2.authors.extend([authors[2], authors[3]])  # Batman: Френк Міллер, Девід Мацукеллі
            m3.authors.append(authors[4])                # Akira: Кацухіро Отомо
            m4.authors.append(authors[5])                # Sandman: Ніл Гейман
            m5.authors.append(authors[0])                # Fantastic Four: Стен Лі

            magazines = [m1, m2, m3, m4, m5]
            session.add_all(magazines)
            session.commit()

            # 3. Створення Магазинів (INSERT INTO store)
            stores = [
                Store(name="Комікс-Центр", address="Львів, вул. Руська, 10"),       # id 1
                Store(name="Світ Журналів", address="Київ, вул. Хрещатик, 22"),     # id 2
                Store(name="Манга Хаб", address="Одеса, вул. Дерибасівська, 5"),    # id 3
            ]
            session.add_all(stores)
            session.commit()

            # 4. Створення Відділів (INSERT INTO department)
            departments = [
                Department(store_id=stores[0].store_id, dept_number=1, name="Супергерої", capacity=200),           # id 1
                Department(store_id=stores[0].store_id, dept_number=2, name="Манга", capacity=150),                # id 2
                Department(store_id=stores[1].store_id, dept_number=1, name="Американські комікси", capacity=300), # id 3
                Department(store_id=stores[1].store_id, dept_number=2, name="Журнали", capacity=100),              # id 4
                Department(store_id=stores[2].store_id, dept_number=1, name="Манга та аніме", capacity=250),       # id 5
            ]
            session.add_all(departments)
            session.commit()

            # 5. Створення Складу (INSERT INTO stock)
            stocks = [
                Stock(department_id=departments[0].department_id, magazine_id=magazines[0].magazine_id, quantity=3),
                Stock(department_id=departments[0].department_id, magazine_id=magazines[1].magazine_id, quantity=10),
                Stock(department_id=departments[1].department_id, magazine_id=magazines[2].magazine_id, quantity=12),
                Stock(department_id=departments[2].department_id, magazine_id=magazines[0].magazine_id, quantity=2),
                Stock(department_id=departments[2].department_id, magazine_id=magazines[3].magazine_id, quantity=7),
                Stock(department_id=departments[3].department_id, magazine_id=magazines[3].magazine_id, quantity=4),
                Stock(department_id=departments[4].department_id, magazine_id=magazines[2].magazine_id, quantity=8),
                Stock(department_id=departments[0].department_id, magazine_id=magazines[4].magazine_id, quantity=10),
                Stock(department_id=departments[1].department_id, magazine_id=magazines[3].magazine_id, quantity=10),
                Stock(department_id=departments[2].department_id, magazine_id=magazines[2].magazine_id, quantity=5),
            ]
            session.add_all(stocks)
            session.commit()

            # 6. Створення Покупців (INSERT INTO customer)
            customers = [
                Customer(email="olena.kovalenko@example.com", full_name="Коваленко Олена Петрівна", birth_date=datetime.strptime("2001-05-14", "%Y-%m-%d").date(), address="Львів, вул. Зелена, 15", phone="+380501112233"),
                Customer(email="andriy.shevchenko@example.com", full_name="Шевченко Андрій Іванович", birth_date=datetime.strptime("1995-11-02", "%Y-%m-%d").date(), address="Київ, вул. Сагайдачного, 8", phone="+380672223344"),
                Customer(email="maria.bondar@example.com", full_name="Бондар Марія Олегівна", birth_date=datetime.strptime("2008-03-21", "%Y-%m-%d").date(), address="Одеса, вул. Пушкінська, 12", phone="+380633334455"),
                Customer(email="dmytro.melnyk@example.com", full_name="Мельник Дмитро Сергійович", birth_date=datetime.strptime("1988-07-30", "%Y-%m-%d").date(), address="Львів, вул. Личаківська, 40", phone="+380504445566"),
                Customer(email="sofiia.tkachenko@example.com", full_name="Ткаченко Софія Андріївна", birth_date=datetime.strptime("2010-01-09", "%Y-%m-%d").date(), address="Київ, вул. Липська, 3", phone="+380965556677"),
            ]
            session.add_all(customers)
            session.commit()

            # 7. Створення Продажів (INSERT INTO sale)
            # ВАЖЛИВО: під час додавання розпродажів відпрацює ваш тригер СУБД,
            # який автоматично зменшить кількість одиниць у stock та заповнить best_store_id у customer!
            sales = [
                Sale(customer_id=customers[0].customer_id, department_id=departments[0].department_id, magazine_id=magazines[0].magazine_id, sale_date=datetime.strptime("2026-08-10", "%Y-%m-%d").date()),
                Sale(customer_id=customers[0].customer_id, department_id=departments[0].department_id, magazine_id=magazines[1].magazine_id, sale_date=datetime.strptime("2026-09-20", "%Y-%m-%d").date()),
                Sale(customer_id=customers[0].customer_id, department_id=departments[1].department_id, magazine_id=magazines[2].magazine_id, sale_date=datetime.strptime("2026-10-01", "%Y-%m-%d").date()),
                Sale(customer_id=customers[1].customer_id, department_id=departments[1].department_id, magazine_id=magazines[2].magazine_id, sale_date=datetime.strptime("2026-07-15", "%Y-%m-%d").date()),
                Sale(customer_id=customers[1].customer_id, department_id=departments[1].department_id, magazine_id=magazines[3].magazine_id, sale_date=datetime.strptime("2026-09-28", "%Y-%m-%d").date()),
                Sale(customer_id=customers[2].customer_id, department_id=departments[2].department_id, magazine_id=magazines[3].magazine_id, sale_date=datetime.strptime("2026-10-02", "%Y-%m-%d").date()),
                Sale(customer_id=customers[3].customer_id, department_id=departments[0].department_id, magazine_id=magazines[0].magazine_id, sale_date=datetime.strptime("2026-06-01", "%Y-%m-%d").date()),
                Sale(customer_id=customers[3].customer_id, department_id=departments[0].department_id, magazine_id=magazines[4].magazine_id, sale_date=datetime.strptime("2026-08-25", "%Y-%m-%d").date()),
                Sale(customer_id=customers[4].customer_id, department_id=departments[2].department_id, magazine_id=magazines[2].magazine_id, sale_date=datetime.strptime("2026-10-03", "%Y-%m-%d").date()),
            ]
            session.add_all(sales)
            session.commit()

            print(" Базу даних успішно заповнено точними тестовими даними!")
        except Exception as e:
            session.rollback()
            print(f"Помилка заповнення бази даних: {e}")