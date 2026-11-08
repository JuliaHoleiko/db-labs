from typing import List
from sqlalchemy import CheckConstraint, ForeignKey, Integer, SmallInteger, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from models.base import Base


class Department(Base):
    __tablename__ = "department"

    department_id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    store_id: Mapped[int] = mapped_column(
        ForeignKey("store.store_id", ondelete="CASCADE"), nullable=False
    )
    dept_number: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    capacity: Mapped[int] = mapped_column(Integer, nullable=False)

    __table_args__ = (
        UniqueConstraint("store_id", "dept_number", name="uq_store_dept_number"),
        CheckConstraint("capacity >= 0", name="chk_dept_capacity"),
    )

    store: Mapped["Store"] = relationship(back_populates="departments")
    stocks: Mapped[List["Stock"]] = relationship(
        back_populates="department", cascade="all, delete-orphan"
    )