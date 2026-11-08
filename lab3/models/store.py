from typing import List, Optional
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from models.base import Base


class Store(Base):
    __tablename__ = "store"

    store_id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False, unique=True)
    address: Mapped[Optional[str]] = mapped_column(String(300))

    departments: Mapped[List["Department"]] = relationship(
        back_populates="store", cascade="all, delete-orphan"
    )
    favorite_by_customers: Mapped[List["Customer"]] = relationship(
        back_populates="best_store"
    )