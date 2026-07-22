from typing import Optional
from pydantic import BaseModel


# Schema used when registering a new user
class UserCreate(BaseModel):
  username: str
  email: str
  password: str


# Schema used when returning user data in responses
class UserResponse(BaseModel):
  id: int
  username: str
  email: str

  class Config:
    from_attributes = True


# Schema used when adding a new street food spot
class FoodSpotCreate(BaseModel):
  name: str
  description: Optional[str] = None
  address: str
  user_id: int


# Schema used when returning food spot data in responses
class FoodSpotResponse(BaseModel):
  id: int
  name: str
  description: Optional[str] = None
  address: str
  user_id: int

  class Config:
    from_attributes = True


# Schema used when creating a review for a food spot
class ReviewCreate(BaseModel):
  rating: int
  comment: Optional[str] = None
  image_url: Optional[str] = None
  user_id: int


# Schema used when returning review data in responses
class ReviewResponse(BaseModel):
  id: int
  spot_id: int
  user_id: int
  rating: int
  comment: Optional[str] = None
  image_url: Optional[str] = None

  class Config:
    from_attributes = True