from typing import List
from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from models.base import Base


class MagazineAuthor(Base):
    __tablename__ = "magazine_author"

    magazine_id: Mapped[int] = mapped_column(
        ForeignKey("magazine.magazine_id", ondelete="CASCADE"), primary_key=True
    )
    author_id: Mapped[int] = mapped_column(
        ForeignKey("author.author_id"), primary_key=True
    )


class Author(Base):
    __tablename__ = "author"

    author_id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    full_name: Mapped[str] = mapped_column(String(200), nullable=False)

    magazines: Mapped[List["Magazine"]] = relationship(
        secondary="magazine_author", back_populates="authors"
    )