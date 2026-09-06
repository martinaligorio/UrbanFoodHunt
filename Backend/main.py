import math
import httpx
from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Form  # type: ignore[import-not-found]
from sqlalchemy.orm import Session  # type: ignore[import-not-found]
from database import get_db, engine
import models
import schemas
import shutil
import os
# StaticFiles is provided by Starlette, which is FastAPI's underlying ASGI toolkit.
from starlette.staticfiles import StaticFiles  # type: ignore[import-not-found]

app = FastAPI()
models.Base.metadata.create_all(bind=engine)

YELP_API_KEY = "QGh5a62SpWUXrXsO7BxGGvt6LvM9CDw8p3OLJSThY0qXXJppqNmydFaP7mgMTj8GmAAm9r9dRylNMJghruF6epmrcY7by0HFdSnlq_dGVJ90aIwz0U1k4JvnivqWanYx"
UPLOAD_DIR = "static/images"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/")
def read_root():
    return {"message": "UrbanFoodHunt Backend is running!"}

@app.get("/spots/nearby")
async def get_nearby_spots(lat: float, lon: float, radius_km: float = 5.0):
    """
    Fetch nearby food spots from Yelp Fusion API using GPS coordinates and a dynamic radius,
    returning name, address, rating, review count, and distance.
    """
    url = "https://api.yelp.com/v3/businesses/search"
    
    headers = {
        "Authorization": f"Bearer {YELP_API_KEY}",
        "accept": "application/json"
    }
    
    # Convert km to meters for Yelp (Yelp max allowed is 40000 meters / 40 km)
    radius_meters = int(min(max(radius_km * 1000, 500), 40000))
    
    params = {
        "latitude": lat,
        "longitude": lon,
        "term": "restaurants",
        "radius": radius_meters, 
        "limit": 30
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, headers=headers, params=params)
            
            if response.status_code != 200:
                print(f"Yelp API error: {response.text}")
                return []
                
            data = response.json()
            businesses = data.get("businesses", [])
            
            spots = []
            for biz in businesses:
                location = biz.get("location", {})
                address_parts = location.get("display_address", ["Address not specified"])
                address_str = ", ".join(address_parts)
                
                distance_meters = biz.get("distance", 0.0)
                distance_km = round(distance_meters / 1000.0, 2)
                
                spots.append({
                    "id": biz.get("id"),
                    "name": biz.get("name"),
                    "address": address_str,
                    "rating": biz.get("rating", 0.0),
                    "review_count": biz.get("review_count", 0),
                    "latitude": biz.get("coordinates", {}).get("latitude"),
                    "longitude": biz.get("coordinates", {}).get("longitude"),
                    "distance_km": distance_km
                })
            
            # Extra backend safety filter based on user-selected distance
            filtered_spots = [s for s in spots if s["distance_km"] <= radius_km]
            # Default sorting from closest to farthest
            filtered_spots.sort(key=lambda x: x["distance_km"])
            
            return filtered_spots

    except Exception as e:
        print(f"Error fetching data from Yelp API: {e}")
        return []


@app.post("/users/register", response_model=schemas.UserResponse)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    # Check if username already exists
    db_user = db.query(models.User).filter(models.User.username == user.username).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    # In a production app, hash the password here. For university projects, saving it directly or simply is often accepted.
    new_user = models.User(
        username=user.username,
        email=user.email,
        password_hash=user.password  # Semplificato per scopo accademico
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@app.post("/users/login", response_model=schemas.UserResponse)
def login_user(user: schemas.UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.username == user.username, models.User.password_hash == user.password).first()
    if not db_user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password")
    return db_user

@app.post("/spots/{spot_id}/reviews", response_model=schemas.ReviewResponse)
async def create_review(
    spot_id: str,
    rating: int = Form(...),
    comment: str = Form(None),
    user_id: int = Form(...),
    spot_name: str = Form("Yelp Food Spot"), # <-- Riceve il nome del ristorante
    file: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    # Controlla o crea il record del locale nel database locale
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
        # Aggiorna il nome se era generico
        if db_spot.name == "Yelp Food Spot" and spot_name != "Yelp Food Spot":
            db_spot.name = spot_name
            db.commit()

    image_url = None
    if file:
        file_path = os.path.join(UPLOAD_DIR, file.filename)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        image_url = f"/{file_path}" # Es: /static/images/nomefile.jpg

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

# 3. Aggiorna l'endpoint per restituire anche il nome del locale unendo le tabelle:
@app.get("/users/{user_id}/reviews")
def get_user_reviews(user_id: int, db: Session = Depends(get_db)):
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

import os

@app.delete("/reviews/{review_id}")
def delete_review(review_id: int, db: Session = Depends(get_db)):
    db_review = db.query(models.Review).filter(models.Review.id == review_id).first()
    if not db_review:
        raise HTTPException(status_code=404, detail="Review not found")

    # (Opzionale) Rimuove anche il file immagine dal server se esiste
    if db_review.image_url:
        file_path = db_review.image_url.lstrip("/") # Rimuove lo slash iniziale es. "/static/..." -> "static/..."
        if os.path.exists(file_path):
            try:
                os.remove(file_path)
            except Exception as e:
                print(f"Error deleting image file: {e}")

    db.delete(db_review)
    db.commit()
    return {"message": "Review deleted successfully"}

@app.put("/reviews/{review_id}")
async def update_review(
    review_id: int,
    rating: int = Form(...),
    comment: str = Form(None),
    file: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    db_review = db.query(models.Review).filter(models.Review.id == review_id).first()
    if not db_review:
        raise HTTPException(status_code=404, detail="Review not found")

    # Aggiorna i campi testuali
    db_review.rating = rating
    db_review.comment = comment

    # Se viene caricata una nuova foto, la sostituisce
    if file:
        file_path = os.path.join(UPLOAD_DIR, file.filename)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        db_review.image_url = f"/{file_path}"

    db.commit()
    db.refresh(db_review)

    # Recupera il nome del locale associato per restituire la risposta completa
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