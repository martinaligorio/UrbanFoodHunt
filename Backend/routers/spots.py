"""
routers/spots.py
----------------
Handles public cloud service integration (Google Places API) for nearby spot discovery (Requirement 1 & 7).
"""

import httpx
import math
from importlib import import_module

try:
    APIRouter = import_module("fastapi").APIRouter
except ModuleNotFoundError:  # Allow this module to be imported without FastAPI installed.
    class APIRouter:  # type: ignore[no-redef]
        def __init__(self, *args, **kwargs):
            pass

        def get(self, *args, **kwargs):
            def decorator(func):
                return func

            return decorator

router = APIRouter(prefix="/spots", tags=["Food Spots"])

# Sostituisci con la tua chiave API di Google Cloud (Places API)
API_KEY = "AIzaSyAJoNtdjjTGJ0PC9I0lP32-RY3JHvEgmFk"

def haversine(lat1, lon1, lat2, lon2):
    """Calcola la distanza in km tra due punti geografici."""
    if lat2 is None or lon2 is None:
        return 0.0
    R = 6371.0   #raggio della Terra in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.asin(math.sqrt(a))
    return round(R * c, 2)

@router.get("/nearby")
async def get_nearby_spots(lat: float, lon: float, radius_km: float = 5.0):
    """Fetches nearby food spots asynchronously from the Google Places API."""
    url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
    
    # Google accetta il raggio in metri (massimo 50000m)
    radius_meters = int(min(max(radius_km * 1000, 500), 50000))
    
    params = {
        "location": f"{lat},{lon}",
        "radius": radius_meters,
        "type": "restaurant",
        "key": API_KEY
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, params=params)
            
            # AGGIUNGI QUESTI PRINT PER VEDERE TUTTO SU RENDER
            print(f"Google Status Code: {response.status_code}")
            print(f"Google Response Text: {response.text}")
            
            if response.status_code != 200:
                return []
                
            data = response.json()
            results = data.get("results", [])
            
            spots = []
            for place in results:
                location = place.get("geometry", {}).get("location", {})
                lat_biz = location.get("lat")
                lon_biz = location.get("lng")
                
                # Calcoliamo la distanza dal punto dell'utente
                distance_km = haversine(lat, lon, lat_biz, lon_biz)
                
                spots.append({
                    "id": place.get("place_id"),
                    "name": place.get("name"),
                    "address": place.get("vicinity", "Address not specified"),
                    "rating": place.get("rating", 0.0),
                    "review_count": place.get("user_ratings_total", 0),
                    "latitude": lat_biz,
                    "longitude": lon_biz,
                    "distance_km": distance_km,
                    "image_url": None  # Google Places standard Nearby Search non fornisce immagini dirette senza una chiamata aggiuntiva (Place Photos)
                })
            
            # Filtriamo e ordiniamo per distanza
            filtered_spots = [s for s in spots if s["distance_km"] <= radius_km]
            filtered_spots.sort(key=lambda x: x["distance_km"])
            return filtered_spots

    except Exception as e:
        print(f"Error fetching data from Google Places API: {e}")
        return []