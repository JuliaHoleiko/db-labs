from typing import List, Optional
from sqlalchemy import CheckConstraint, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from models.base import Base


class Magazine(Base):
    __tablename__ = "magazine"

    magazine_id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    series: Mapped[Optional[str]] = mapped_column(String(200))
    publisher: Mapped[str] = mapped_column(String(200), nullable=False)
    year: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    isbn: Mapped[str] = mapped_column(String(17), nullable=False, unique=True)

    __table_args__ = (
        CheckConstraint("year BETWEEN 1800 AND 2100", name="chk_magazine_year"),
    )

    authors: Mapped[List["Author"]] = relationship(
        secondary="magazine_author", back_populates="magazines"
    )
    stocks: Mapped[List["Stock"]] = relationship(back_populates="magazine")