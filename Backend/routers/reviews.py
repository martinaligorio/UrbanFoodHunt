"""
routers/reviews.py
----------------
Handles review CRUD operations and Cloudinary cloud image uploads (Requirements 6, 8, & 10).
"""

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form  # type: ignore[import-not-found]
from typing import Any
from database import get_db
import models
import schemas
import cloudinary.uploader  # type: ignore[import-not-found]

router = APIRouter(tags=["Reviews"])


@router.post("/spots/{spot_id}/reviews", response_model=schemas.ReviewResponse)
async def create_review(
    spot_id: str,
    rating: int = Form(...),
    comment: str = Form(None),
    user_id: int = Form(...),
    spot_name: str = Form("Yelp Food Spot"),
    file: UploadFile = File(None),
    db: Any = Depends(get_db)
):
    """Creates a review, uploads images to Cloudinary, and stores data in SQLite."""
    db_spot = db.query(models.FoodSpot).filter(models.FoodSpot.id == spot_id).first()
    if not db_spot:
        db_spot = models.FoodSpot(
            id=spot_id,
            name=spot_name,
            address="Address from Yelp",
            user_id=user_id
        )
        db.add(db_spot)
        db.commit()
    else:
        if db_spot.name == "Yelp Food Spot" and spot_name != "Yelp Food Spot":
            db_spot.name = spot_name
            db.commit()

    image_url = None
    if file:
        upload_result = cloudinary.uploader.upload(file.file)
        image_url = upload_result.get("secure_url")

    new_review = models.Review(
        spot_id=spot_id,
        user_id=user_id,
        rating=rating,
        comment=comment,
        image_url=image_url
    )
    
    db.add(new_review)
    db.commit()
    db.refresh(new_review)
    return new_review


@router.get("/users/{user_id}/reviews")
def get_user_reviews(user_id: int, db: Any = Depends(get_db)):
    """Retrieves all reviews posted by a specific user."""
    results = db.query(models.Review, models.FoodSpot.name)\
        .join(models.FoodSpot, models.Review.spot_id == models.FoodSpot.id)\
        .filter(models.Review.user_id == user_id).all()
    
    reviews_list = []
    for review, spot_name in results:
        reviews_list.append({
            "id": review.id,
            "spot_id": review.spot_id,
            "spot_name": spot_name or "Unknown Spot",
            "user_id": review.user_id,
            "rating": review.rating,
            "comment": review.comment,
            "image_url": review.image_url
        })
    return reviews_list


@router.delete("/reviews/{review_id}")
def delete_review(review_id: int, db: Any = Depends(get_db)):
    """Deletes an existing review by ID."""
    db_review = db.query(models.Review).filter(models.Review.id == review_id).first()
    if not db_review:
        raise HTTPException(status_code=404, detail="Review not found")

    db.delete(db_review)
    db.commit()
    return {"message": "Review deleted successfully"}


@router.put("/reviews/{review_id}")
async def update_review(
    review_id: int,
    rating: int = Form(...),
    comment: str = Form(None),
    file: UploadFile = File(None),
    db: Any = Depends(get_db)
):
    """Updates an existing review's rating, comment, or photo."""
    db_review = db.query(models.Review).filter(models.Review.id == review_id).first()
    if not db_review:
        raise HTTPException(status_code=404, detail="Review not found")

    db_review.rating = rating
    db_review.comment = comment

    if file:
        upload_result = cloudinary.uploader.upload(file.file)
        db_review.image_url = upload_result.get("secure_url")

    db.commit()
    db.refresh(db_review)

    spot = db.query(models.FoodSpot).filter(models.FoodSpot.id == db_review.spot_id).first()
    spot_name = spot.name if spot else "Unknown Spot"

    return {
        "id": db_review.id,
        "spot_id": db_review.spot_id,
        "spot_name": spot_name,
        "user_id": db_review.user_id,
        "rating": db_review.rating,
        "comment": db_review.comment,
        "image_url": db_review.image_url
    }