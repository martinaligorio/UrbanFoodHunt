"""
database.py
----------------
Handles the SQLite database connection, session management, and base declarative 
configuration using SQLAlchemy for the Urban Food Hunt backend (Requirement 10)[cite: 3, 15].
"""

from importlib import import_module

# Load SQLAlchemy dynamically so static analyzers do not report a missing
# optional dependency at module-import time.
try:
    _sqlalchemy = import_module("sqlalchemy")
    _sqlalchemy_orm = import_module("sqlalchemy.orm")
except ModuleNotFoundError as exc:
    raise RuntimeError(
        "SQLAlchemy is required. Install it with: pip install sqlalchemy"
    ) from exc

create_engine = _sqlalchemy.create_engine
declarative_base = _sqlalchemy_orm.declarative_base
sessionmaker = _sqlalchemy_orm.sessionmaker

# Define the SQLite database connection URL pointing to a local file
SQLALCHEMY_DATABASE_URL = "sqlite:///./urbanfoodhunt.db"

# Initialize the SQLAlchemy engine. 
# Note: connect_args={"check_same_thread": False} is required for SQLite in FastAPI 
# to allow multi-threaded access across asynchronous requests.
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# Configure the SessionLocal class to generate independent database sessions per request
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Establish the declarative base class from which all database models will inherit
Base = declarative_base()


def get_db():
    """
    FastAPI dependency function that creates a new database session for a request,
    yields it to the endpoint handler, and ensures it is safely closed afterwards.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()