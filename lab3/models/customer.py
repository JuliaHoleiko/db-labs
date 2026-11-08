from datetime import date
from typing import List, Optional
from sqlalchemy import Date, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from models.base import Base


class Customer(Base):
    __tablename__ = "customer"

    customer_id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(254), nullable=False, unique=True)
    full_name: Mapped[str] = mapped_column(String(250), nullable=False)
    birth_date: Mapped[date] = mapped_column(Date, nullable=False)
    address: Mapped[Optional[str]] = mapped_column(String(300))
    phone: Mapped[Optional[str]] = mapped_column(String(20))
    best_store_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("store.store_id", ondelete="SET NULL")
    )

    best_store: Mapped[Optional["Store"]] = relationship(
        back_populates="favorite_by_customers"
    )
    sales: Mapped[List["Sale"]] = relationship(back_populates="customer")