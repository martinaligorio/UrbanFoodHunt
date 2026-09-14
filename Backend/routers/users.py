"""
routers/users.py
----------------
Handles user authentication and registration endpoints (Requirement 2).
"""

from fastapi import APIRouter, Depends, HTTPException, status  # type: ignore[reportMissingImports]
from typing import Any
from database import get_db
import models
import schemas

router = APIRouter(prefix="/users", tags=["Users"])


@router.post("/register", response_model=schemas.UserResponse)
def register_user(user: schemas.UserCreate, db: Any = Depends(get_db)):
    """Registers a new user account in the database."""
    db_user = db.query(models.User).filter(models.User.username == user.username).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    new_user = models.User(
        username=user.username,
        email=user.email,
        password_hash=user.password
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


@router.post("/login", response_model=schemas.UserResponse)
def login_user(user: schemas.UserLogin, db: Any = Depends(get_db)):
    """Authenticates a user against stored credentials."""
    db_user = db.query(models.User).filter(
        models.User.username == user.username, 
        models.User.password_hash == user.password
    ).first()
    
    if not db_user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password")
    return db_user