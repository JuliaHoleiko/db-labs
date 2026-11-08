from models.base import Base
from models.author import Author, MagazineAuthor
from models.magazine import Magazine
from models.store import Store
from models.department import Department
from models.stock import Stock
from models.customer import Customer
from models.sale import Sale

__all__ = [
    "Base",
    "Author",
    "MagazineAuthor",
    "Magazine",
    "Store",
    "Department",
    "Stock",
    "Customer",
    "Sale",
]