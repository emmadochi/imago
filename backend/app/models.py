"""
SQLAlchemy ORM Models for Imago / Yoetz Application.
Designed for PostgreSQL with support for connection-pooled operations.
"""

import datetime
from typing import Optional
from sqlalchemy import String, Text, Integer, Boolean, DateTime, ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base

class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(128), primary_key=True) # Firebase UID or UUID
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    display_name: Mapped[str] = mapped_column(String(255), nullable=True)
    partner_tier: Mapped[str] = mapped_column(String(64), default="Free", nullable=False)
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.datetime.utcnow, nullable=False
    )
    updated_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow, nullable=False
    )

    # Relationships
    prayers: Mapped[list["PrayerJournal"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    bookmarks: Mapped[list["SermonBookmark"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    highlights: Mapped[list["VerseHighlight"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    payments: Mapped[list["PaymentTransaction"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class PrayerJournal(Base):
    __tablename__ = "prayer_journals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(String(128), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    request_text: Mapped[str] = mapped_column(Text, nullable=False)
    pastoral_response: Mapped[str] = mapped_column(Text, nullable=True)
    is_answered: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    answered_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.datetime.utcnow, nullable=False
    )

    user: Mapped["User"] = relationship(back_populates="prayers")


class SermonBookmark(Base):
    __tablename__ = "sermon_bookmarks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(String(128), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    sermon_title: Mapped[str] = mapped_column(String(255), nullable=False)
    speaker: Mapped[str] = mapped_column(String(255), nullable=True)
    audio_url: Mapped[str] = mapped_column(String(1024), nullable=True)
    timestamp_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    notes: Mapped[str] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.datetime.utcnow, nullable=False
    )

    user: Mapped["User"] = relationship(back_populates="bookmarks")


class VerseHighlight(Base):
    __tablename__ = "verse_highlights"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(String(128), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    book: Mapped[str] = mapped_column(String(64), nullable=False)
    chapter: Mapped[int] = mapped_column(Integer, nullable=False)
    verse: Mapped[int] = mapped_column(Integer, nullable=False)
    color_hex: Mapped[str] = mapped_column(String(16), default="#FCD34D", nullable=False) # e.g. Gold/Amber
    note: Mapped[str] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.datetime.utcnow, nullable=False
    )

    user: Mapped["User"] = relationship(back_populates="highlights")

    __table_args__ = (
        Index("idx_verse_lookup", "user_id", "book", "chapter", "verse"),
    )


class PaymentTransaction(Base):
    __tablename__ = "payment_transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(String(128), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    reference: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    amount: Mapped[int] = mapped_column(Integer, nullable=False) # In kobo or cents
    currency: Mapped[str] = mapped_column(String(16), default="NGN", nullable=False)
    partner_tier: Mapped[str] = mapped_column(String(64), nullable=False)
    frequency: Mapped[str] = mapped_column(String(32), default="monthly", nullable=False)
    channel: Mapped[str] = mapped_column(String(64), nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="pending", nullable=False) # pending, success, failed
    gateway: Mapped[str] = mapped_column(String(32), default="paystack", nullable=False)
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.datetime.utcnow, nullable=False
    )
    paid_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    metadata_json: Mapped[str] = mapped_column(Text, nullable=True)

    user: Mapped[Optional["User"]] = relationship(back_populates="payments")

    __table_args__ = (
        Index("idx_payment_status", "status", "created_at"),
    )


