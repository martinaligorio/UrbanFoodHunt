"""
routers/spots.py
----------------
Handles public cloud service integration (Yelp Fusion API) for nearby spot discovery (Requirement 1 & 7).
"""

import httpx
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

YELP_API_KEY = "QGh5a62SpWUXrXsO7BxGGvt6LvM9CDw8p3OLJSThY0qXXJppqNmydFaP7mgMTj8GmAAm9r9dRylNMJghruF6epmrcY7by0HFdSnlq_dGVJ90aIwz0U1k4JvnivqWanYx"


@router.get("/nearby")
async def get_nearby_spots(lat: float, lon: float, radius_km: float = 5.0):
    """Fetches nearby food spots asynchronously from the Yelp Fusion API."""
    url = "https://api.yelp.com/v3/businesses/search"
    
    headers = {
        "Authorization": f"Bearer {YELP_API_KEY}",
        "accept": "application/json"
    }
    
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
                    "distance_km": distance_km,
                    "image_url": biz.get("image_url")  
                })
            
            filtered_spots = [s for s in spots if s["distance_km"] <= radius_km]
            filtered_spots.sort(key=lambda x: x["distance_km"])
            return filtered_spots

    except Exception as e:
        print(f"Error fetching data from Yelp API: {e}")
        return []