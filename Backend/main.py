import database
import models
import schemas
from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy.orm import Session
import shutil
import os
from fastapi import File, UploadFile
import httpx

# Automatically create tables in the SQLite database if they don't exist
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="UrbanFoodHunt API", version="1.0.0", description="API for UrbanFoodHunt: Street Food Stalls and Local Markets")

# Folder where temporary uploaded images are stored before cloud sync
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Google Places API Key obtained from Google Cloud Console
GOOGLE_MAPS_API_KEY = "AIzaSyAJoNtdjjTGJ0PC9I0lP32-RY3JHvEgmFk"

# Dependency to get an active database session for each request
def get_db():
  db = database.SessionLocal()
  try:
    yield db
  finally:
    db.close()


@app.get("/")
def read_root():
  return {
      "message": (
          "Welcome to UrbanFoodHunt! The server is active and the DB is ready."
      )
  }


# --- USERS ENDPOINTS ---


@app.post("/users/", response_model=schemas.UserResponse)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
  db_user = (
      db.query(models.User).filter(models.User.username == user.username).first()
  )
  if db_user:
    raise HTTPException(status_code=400, detail="Username already registered")

  new_user = models.User(
      username=user.username, email=user.email, password_hash=user.password
  )
  db.add(new_user)
  db.commit()
  db.refresh(new_user)
  return new_user


@app.get("/users/", response_model=list[schemas.UserResponse])
def get_users(skip: int = 0, limit: int = 10, db: Session = Depends(get_db)):
  users = db.query(models.User).offset(skip).limit(limit).all()
  return users


# --- FOOD SPOTS ENDPOINTS ---


@app.post("/spots/", response_model=schemas.FoodSpotResponse)
def create_food_spot(
    spot: schemas.FoodSpotCreate, db: Session = Depends(get_db)
):
  db_user = (
      db.query(models.User).filter(models.User.id == spot.user_id).first()
  )
  if not db_user:
    raise HTTPException(status_code=404, detail="User not found")

  new_spot = models.FoodSpot(
      name=spot.name,
      description=spot.description,
      address=spot.address,
      user_id=spot.user_id,
  )
  db.add(new_spot)
  db.commit()
  db.refresh(new_spot)
  return new_spot


@app.get("/spots/", response_model=list[schemas.FoodSpotResponse])
def get_food_spots(
    skip: int = 0, limit: int = 10, db: Session = Depends(get_db)
):
  spots = db.query(models.FoodSpot).offset(skip).limit(limit).all()
  return spots


# --- REVIEWS ENDPOINTS ---


# Endpoint to add a review to a specific food spot (POST)
@app.post("/spots/{spot_id}/reviews/", response_model=schemas.ReviewResponse)
def create_review(
    spot_id: int, review: schemas.ReviewCreate, db: Session = Depends(get_db)
):
  # Check if the food spot exists
  db_spot = (
      db.query(models.FoodSpot).filter(models.FoodSpot.id == spot_id).first()
  )
  if not db_spot:
    raise HTTPException(status_code=404, detail="Food spot not found")

  # Check if the user exists
  db_user = (
      db.query(models.User).filter(models.User.id == review.user_id).first()
  )
  if not db_user:
    raise HTTPException(status_code=404, detail="User not found")

  # Check if the user has already reviewed this food spot
  existing_review = (
      db.query(models.Review)
      .filter(
          models.Review.spot_id == spot_id,
          models.Review.user_id == review.user_id,
      )
      .first()
  )
  if existing_review:
    raise HTTPException(
        status_code=400, detail="You have already reviewed this food spot"
    )

  # Create and save the new review record
  new_review = models.Review(
      spot_id=spot_id,
      user_id=review.user_id,
      rating=review.rating,
      comment=review.comment,
      image_url=review.image_url,
  )
  db.add(new_review)
  db.commit()
  db.refresh(new_review)
  return new_review


# Endpoint to list all reviews for a specific food spot (GET)
@app.get(
    "/spots/{spot_id}/reviews/", response_model=list[schemas.ReviewResponse]
)
def get_spot_reviews(spot_id: int, db: Session = Depends(get_db)):
  reviews = (
      db.query(models.Review).filter(models.Review.spot_id == spot_id).all()
  )
  return reviews

# Endpoint to upload a food image to Cloud Storage (Requirement 8)
@app.post("/upload-image/")
async def upload_image(file: UploadFile = File(...)):
  # In a production environment with Google Cloud Storage / Firebase Storage,
  # you would upload the 'file.file' stream directly to the cloud bucket here
  # and retrieve the public HTTPS URL.

  file_path = os.path.join(UPLOAD_DIR, file.filename)

  # Save the file locally as a simulation of cloud staging
  with open(file_path, "wb") as buffer:
    shutil.copyfileobj(file.file, buffer)

  # Generate the public URL reference (simulating cloud storage response)
  public_url = f"http://127.0.0.1:8000/{file_path}"

  return {
      "filename": file.filename,
      "image_url": public_url,
      "message": "Image successfully uploaded to cloud storage simulation",
  }
# Public Cloud API Endpoint (Requirement 1 & 7)
# Checks the live status (open/closed) of a food spot using Google Places API
import httpx


import httpx


@app.get("/spots/{spot_id}/live-status")
async def get_spot_live_status(spot_id: int, db: Session = Depends(get_db)):
  # Verify if the food spot exists in our local database
  db_spot = (
      db.query(models.FoodSpot).filter(models.FoodSpot.id == spot_id).first()
  )
  if not db_spot:
    raise HTTPException(status_code=404, detail="Food spot not found")

  query_name = db_spot.name
  overpass_url = "https://overpass-api.de/api/interpreter"

  # Improved Overpass QL query: searches nodes and ways for food/restaurants in Italy bounding box
  overpass_query = f"""
    [out:json][timeout:15];
    (
      node["amenity"~"restaurant|fast_food|cafe|pub"]["name"~"{query_name}", i](35.0,6.0,47.0,19.0);
      way["amenity"~"restaurant|fast_food|cafe|pub"]["name"~"{query_name}", i](35.0,6.0,47.0,19.0);
    );
    out 1;
    """

  try:
    async with httpx.AsyncClient() as client:
      response = await client.post(overpass_url, data=overpass_query)

      if response.status_code == 200:
        data = response.json()
        elements = data.get("elements", [])

        if elements:
          place = elements[0]
          tags = place.get("tags", {})
          opening_hours = tags.get(
              "opening_hours", "Orari non specificati su OSM"
          )

          return {
              "spot_id": db_spot.id,
              "spot_name": db_spot.name,
              "osm_id": place.get("id"),
              "opening_hours": opening_hours,
              "is_open_now": opening_hours != "Closed",
              "source": "OpenStreetMap Public Cloud API (Requirement 1)",
          }

      # Fallback simulation if the specific name is not found in OSM database
      return {
          "spot_id": db_spot.id,
          "spot_name": db_spot.name,
          "address": db_spot.address,
          "is_open_now": True,
          "source": "OpenStreetMap API Simulation Fallback (Requirement 1)",
      }

  except Exception as e:
    raise HTTPException(
        status_code=503,
        detail=f"Public Cloud API unavailable: {str(e)}",
    )