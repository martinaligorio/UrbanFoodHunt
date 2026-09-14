"""
main.py
----------------
Clean entry point for the Urban Food Hunt FastAPI backend.
Initializes the app, database tables, Cloudinary config, and includes all feature routers.
"""

from fastapi import FastAPI  # pyright: ignore[reportMissingImports]
from database import engine
import models
import cloudinary  # pyright: ignore[reportMissingImports]
from routers import users, spots, reviews

# Initialize FastAPI application instance
app = FastAPI(
    title="Urban Food Hunt API",
    description="Backend REST API for the Urban Food Hunt mobile application.",
    version="1.0.0"
)

# Automatically create database tables
models.Base.metadata.create_all(bind=engine)

# Configure Cloudinary
cloudinary.config(secure=True)

# Include modular routers
app.include_router(users.router)
app.include_router(spots.router)
app.include_router(reviews.router)


@app.get("/")
def read_root():
    """Root health check endpoint to verify backend connectivity."""
    return {"message": "UrbanFoodHunt Backend is running!"}