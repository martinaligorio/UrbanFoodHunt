import database
import models
import schemas
from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy.orm import Session

# Automatically create tables in the SQLite database if they don't exist
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="UrbanFoodHunt API")


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
      "message": "Welcome to UrbanFoodHunt! The server is active and the DB is ready."
  }


# Endpoint to create a new user (POST)
@app.post("/users/", response_model=schemas.UserResponse)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
  # Check if the username is already taken
  db_user = (
      db.query(models.User).filter(models.User.username == user.username).first()
  )
  if db_user:
    raise HTTPException(status_code=400, detail="Username already registered")

  # Create the user record (Note: in production, hash the password!)
  new_user = models.User(
      username=user.username, email=user.email, password_hash=user.password
  )
  db.add(new_user)
  db.commit()
  db.refresh(new_user)
  return new_user

# GET to read data
# Endpoint to list all registered users (GET)
@app.get("/users/", response_model=list[schemas.UserResponse])
def get_users(skip: int = 0, limit: int = 10, db: Session = Depends(get_db)):
  users = db.query(models.User).offset(skip).limit(limit).all()
  return users


# --- FOOD SPOTS ENDPOINTS ---


# Endpoint to create a new street food spot (POST)
@app.post("/spots/", response_model=schemas.FoodSpotResponse)
def create_food_spot(
    spot: schemas.FoodSpotCreate, db: Session = Depends(get_db)
):
  # Verify if the user exists before adding a food spot
  db_user = (
      db.query(models.User).filter(models.User.id == spot.user_id).first()
  )
  if not db_user:
    raise HTTPException(status_code=404, detail="User not found")

  # Create and save the new food spot record in the database
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


# Endpoint to list all registered street food spots (GET)
@app.get("/spots/", response_model=list[schemas.FoodSpotResponse])
def get_food_spots(
    skip: int = 0, limit: int = 10, db: Session = Depends(get_db)
):
  spots = db.query(models.FoodSpot).offset(skip).limit(limit).all()
  return spots