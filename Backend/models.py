"""
models.py
----------------
Defines the SQLAlchemy relational database models for the Urban Food Hunt backend:
1. User: Manages user accounts and authentication credentials (Requirement 2)[cite: 13].
2. FoodSpot: Represents food locations and restaurants fetched or reviewed.
3. Review: Stores user reviews, ratings, comments, and cloud image URLs (Requirements 8 & 10)[cite: 13].
"""

from database import Base
from sqlalchemy import Column, ForeignKey, Integer, String, Text  # type: ignore[reportMissingImports]
from sqlalchemy.orm import relationship  # type: ignore[reportMissingImports]


class User(Base):
    """
    User model representing registered accounts in the database.
    Satisfies Requirement 2 (Support multiple users with login and authentication)[cite: 13].
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)

    # Relationships to associate users with their created spots and reviews
    spots = relationship("FoodSpot", back_populates="owner")
    reviews = relationship("Review", back_populates="author")


class FoodSpot(Base):
    """
    FoodSpot model representing restaurants or food locations explored by users.
    """
    __tablename__ = "food_spots"

    id = Column(String, primary_key=True, index=True)  # Yelp ID or unique string identifier
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String, index=True)
    description = Column(Text, nullable=True)
    address = Column(String)

    # Relationships linking the spot to its creator and associated reviews
    owner = relationship("User", back_populates="spots")
    reviews = relationship(
        "Review", back_populates="spot", cascade="all, delete-orphan"
    )


class Review(Base):
    """
    Review model storing ratings, comments, and cloud-hosted image links.
    Satisfies Requirement 8 (Cloud features/Cloudinary image hosting) and 
    Requirement 10 (SQL storage service via REST API)[cite: 13].
    """
    __tablename__ = "reviews"

    id = Column(Integer, primary_key=True, index=True)
    spot_id = Column(String, ForeignKey("food_spots.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    rating = Column(Integer)
    comment = Column(Text, nullable=True)
    image_url = Column(String, nullable=True)  # Stores secure cloud storage URLs (e.g., Cloudinary)

    # Relationships linking the review back to its spot and author
    spot = relationship("FoodSpot", back_populates="reviews")
    author = relationship("User", back_populates="reviews")