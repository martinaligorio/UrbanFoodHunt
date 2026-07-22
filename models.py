from database import Base
from sqlalchemy import Column, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

# Qui definiamo le tabelle relazionali adatte a un app di street food: gli utenti (users), i chioschi o 
# mercati scoperti (food_spots) e le relative recensioni con foto (reviews) 


class User(Base):
  __tablename__ = "users"
  # primary_key=True, È la chiave primaria. Un identificatore numerico intero che si auto-incrementa e serve a distinguere in modo univoco ogni utente nel database. L'indice (index=True) velocizza le ricerche basate sull'ID.
  id = Column(Integer, primary_key=True, index=True)
  # unique=True, Garantisce che ogni username sia unico nel database, evitando duplicati. L'indice (index=True) velocizza le ricerche basate sull'username.
  username = Column(String, unique=True, index=True)
  email = Column(String, unique=True, index=True)
  password_hash = Column(String)

  spots = relationship("FoodSpot", back_populates="owner")


class FoodSpot(Base):
  __tablename__ = "food_spots"

  id = Column(Integer, primary_key=True, index=True)
  # ForeignKey("users.id") È una chiave esterna (Foreign Key). Collega il chiosco all'utente specifico che lo ha aggiunto per primo all'app. Crea una relazione logica: chi ha creato questo spot?
  user_id = Column(Integer, ForeignKey("users.id"))
  name = Column(String, index=True)
  description = Column(Text)
  address = Column(String)

  owner = relationship("User", back_populates="spots")
  reviews = relationship("Review", back_populates="spot")


class Review(Base):
  __tablename__ = "reviews"

  id = Column(Integer, primary_key=True, index=True)
  spot_id = Column(Integer, ForeignKey("food_spots.id"))
  user_id = Column(Integer, ForeignKey("users.id"))
  rating = Column(Integer)
  comment = Column(Text)
  image_url = Column(String, nullable=True)

  spot = relationship("FoodSpot", back_populates="reviews")