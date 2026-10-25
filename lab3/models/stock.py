from typing import List
from sqlalchemy import CheckConstraint, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from models.base import Base


class Stock(Base):
    __tablename__ = "stock"

    department_id: Mapped[int] = mapped_column(
        ForeignKey("department.department_id", ondelete="CASCADE"), primary_key=True
    )
    magazine_id: Mapped[int] = mapped_column(
        ForeignKey("magazine.magazine_id"), primary_key=True
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    __table_args__ = (
        CheckConstraint("quantity >= 0", name="chk_stock_quantity"),
    )

    department: Mapped["Department"] = relationship(back_populates="stocks")
    magazine: Mapped["Magazine"] = relationship(back_populates="stocks")
    sales: Mapped[List["Sale"]] = relationship(back_populates="stock")