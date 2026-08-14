from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# SQLite database file path for UrbanFoodHunt
SQLALCHEMY_DATABASE_URL = "sqlite:///./urbanfoodhunt.db"

# Create the SQLite database engine
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# Create a session local class for database operations
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for our models to inherit from
Base = declarative_base()


# Dependency to get the database session in FastAPI endpoints
def get_db():
  db = SessionLocal()
  try:
    yield db
  finally:
    db.close()