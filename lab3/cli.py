import os
import click
from sqlalchemy import text
from api.engine import DBConn
from models.base import Base
from scripts import database
from queries.common import run_all_queries

from models import *


@click.group()
def cli():
    DBConn()


@cli.command(help='Створити таблиці та тригери в БД')
def create_tables():
    # 1. Створення таблиць
    Base.metadata.create_all(DBConn.engine)
    click.echo(" Таблиці успішно створені.")

    # 2. Зчитування та виконання SQL-скрипта тригерів
    triggers_path = os.path.join(os.path.dirname(__file__), "scripts", "triggers.sql")
    
    if os.path.exists(triggers_path):
        with open(triggers_path, "r", encoding="utf-8") as file:
            triggers_sql = file.read()
            
        with DBConn.engine.connect() as connection:
            connection.execute(text(triggers_sql))
            connection.commit()
            
        click.echo(" Тригери успішно створені в БД!")
    else:
        click.echo(" Файл scripts/triggers.sql не знайдено.")


@cli.command(help='Видалити таблиці в БД')
def drop_tables():
    Base.metadata.drop_all(DBConn.engine)
    click.echo(" Таблиці видалено.")


@cli.command(help='Заповнити БД тестовими даними')
def fill_db():
    database.fill_db()


@cli.command(help="Виконати тестові ORM-запити")
def run_queries():
    run_all_queries()


if __name__ == '__main__':
    cli()