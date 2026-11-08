from datetime import date
from sqlalchemy import Date, ForeignKey, ForeignKeyConstraint, Integer, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from models.base import Base


class Sale(Base):
    __tablename__ = "sale"

    sale_id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    customer_id: Mapped[int] = mapped_column(
        ForeignKey("customer.customer_id"), nullable=False
    )
    department_id: Mapped[int] = mapped_column(Integer, nullable=False)
    magazine_id: Mapped[int] = mapped_column(Integer, nullable=False)
    
    # Використовуємо func.current_date() замість рядка "current"
    sale_date: Mapped[date] = mapped_column(
        Date, nullable=False, server_default=func.current_date()
    )

    __table_args__ = (
        ForeignKeyConstraint(
            ["department_id", "magazine_id"],
            ["stock.department_id", "stock.magazine_id"],
            name="fk_sale_stock",
        ),
    )

    customer: Mapped["Customer"] = relationship(back_populates="sales")
    stock: Mapped["Stock"] = relationship(back_populates="sales")