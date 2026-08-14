from database import Base
from sqlalchemy import Column, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship


# User model (Requirement 2: Multi-users support)
class User(Base):
  __tablename__ = "users"

  id = Column(Integer, primary_key=True, index=True)
  username = Column(String, unique=True, index=True)
  email = Column(String, unique=True, index=True)
  password_hash = Column(String)

  # Relationship with food spots and reviews
  spots = relationship("FoodSpot", back_populates="owner")
  reviews = relationship("Review", back_populates="author")


# Food Spot model (Street food stalls and local markets)
class FoodSpot(Base):
  __tablename__ = "food_spots"

  id = Column(Integer, primary_key=True, index=True)
  user_id = Column(Integer, ForeignKey("users.id"))
  name = Column(String, index=True)
  description = Column(Text)
  address = Column(String)

  # Relationships
  owner = relationship("User", back_populates="spots")
  reviews = relationship(
      "Review", back_populates="spot", cascade="all, delete-orphan"
  )


# Review model (Includes ratings, comments, and cloud image URLs - Requirement 8 & 10)
class Review(Base):
  __tablename__ = "reviews"

  id = Column(Integer, primary_key=True, index=True)
  spot_id = Column(Integer, ForeignKey("food_spots.id"))
  user_id = Column(Integer, ForeignKey("users.id"))
  rating = Column(Integer)
  comment = Column(Text)
  image_url = Column(String, nullable=True)  # Cloud Storage image link

  # Relationships
  spot = relationship("FoodSpot", back_populates="reviews")
  author = relationship("User", back_populates="reviews")