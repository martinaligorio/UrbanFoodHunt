"""
schemas.py
----------------
Defines the Pydantic data validation and serialization schemas for incoming and 
outgoing data across the Urban Food Hunt REST API endpoints.
"""

from typing import Optional
from pydantic import BaseModel, ConfigDict  # pyright: ignore[reportMissingImports]


class UserCreate(BaseModel):
    """
    Schema validating user registration requests.
    Required fields: username, email, and password.
    """
    username: str
    email: str
    password: str


class UserResponse(BaseModel):
    """
    Schema defining the safe user data returned in API responses 
    (excludes sensitive fields like raw passwords).
    """
    id: int
    username: str
    email: str

    model_config = ConfigDict(from_attributes=True)


class FoodSpotCreate(BaseModel):
    """
    Schema validating requests when adding a new food spot or restaurant.
    """
    name: str
    description: Optional[str] = None
    address: str
    user_id: int


class FoodSpotResponse(BaseModel):
    """
    Schema validating the food spot details returned by API responses.
    """
    id: int
    name: str
    description: Optional[str] = None
    address: str
    user_id: int

    model_config = ConfigDict(from_attributes=True)


class ReviewCreate(BaseModel):
    """
    Schema validating incoming review creation data (ratings, text comments, user ID).
    """
    rating: int
    comment: Optional[str] = None
    image_url: Optional[str] = None
    user_id: int


class ReviewResponse(BaseModel):
    """
    Schema defining review details returned by API endpoints, 
    including links to cloud storage images.
    """
    id: int
    spot_id: str
    user_id: int
    rating: int
    comment: Optional[str] = None
    image_url: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class UserLogin(BaseModel):
    """
    Schema validating user login credentials (username and password).
    """
    username: str
    password: str