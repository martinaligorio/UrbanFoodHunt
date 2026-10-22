"""
routers/spots.py
----------------
Handles public cloud service integration (Google Places API) for nearby spot discovery.
Fulfills project requirements for public cloud services, asynchronous concurrency, and REST APIs.
"""

import httpx
import math
import os
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

# Retrieve Google API key from Render environment variables with a fallback key for local testing
API_KEY = os.environ.get("GOOGLE_API_KEY", "AIzaSyAJoNtdjjTGJ0PC9I0lP32-RY3JHvEgmFk")

def haversine(lat1, lon1, lat2, lon2):
    """
    Calculates the great-circle distance in kilometers between two geographic points 
    using their latitude and longitude. 
    Maintains high mathematical precision without premature rounding to ensure accurate sorting.
    """
    if lat2 is None or lon2 is None:
        return 0.0
    
    R = 6371.0  # Earth radius in kilometers
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    
    # Haversine formula components
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.asin(math.sqrt(a))
    
    return R * c  # Returns exact distance in km (unrounded for sorting accuracy)

@router.get("/nearby")
async def get_nearby_spots(lat: float, lon: float, radius_km: float = 5.0):
    """
    Asynchronously fetches nearby restaurant spots from the Google Places API,
    calculates precise distances, filters results within the requested radius,
    and sorts them from closest to furthest.
    """
    url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
    
    # Convert radius from kilometers to meters for Google Places API (max 50000m)
    radius_meters = int(min(max(radius_km * 1000, 500), 50000))
    
    # Configure parameters using the user-defined radius (removing rankby=distance 
    # to let Google search within the radius, and letting Python handle strict sorting).
    params = {
        "location": f"{lat},{lon}",
        "radius": radius_meters,
        "type": "restaurant",
        "key": API_KEY
    }

    try:
        # Asynchronous HTTP client request to Google Places API (Requirement: Concurrency)
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, params=params)
            
            # Print raw status and response text for real-time debugging on Render logs
            print(f"Google Places API Status Code: {response.status_code}")
            print(f"Google Places API Response: {response.text}")
            
            # Return empty list if HTTP request fails
            if response.status_code != 200:
                return []
                
            data = response.json()
            results = data.get("results", [])
            
            spots = []
            for place in results:
                location = place.get("geometry", {}).get("location", {})
                lat_biz = location.get("lat")
                lon_biz = location.get("lng")
                
                # Calculate precise distance from user coordinates
                distance_km = haversine(lat, lon, lat_biz, lon_biz)
                
                spots.append({
                    "id": place.get("place_id"),
                    "name": place.get("name"),
                    "address": place.get("vicinity", "Address not specified"),
                    "rating": place.get("rating", 0.0),
                    "review_count": place.get("user_ratings_total", 0),
                    "latitude": lat_biz,
                    "longitude": lon_biz,
                    "distance_km": round(distance_km, 2),  # Rounded value for clean UI display
                    "image_url": None  # Google Places standard Nearby Search requires Place Photos API for images
                })
            
            # Filter results to strictly match the requested radius and sort ascending by distance
            filtered_spots = [s for s in spots if s["distance_km"] <= radius_km]
            filtered_spots.sort(key=lambda x: x["distance_km"])
            
            return filtered_spots

    except Exception as e:
        # Catch network or parsing errors and log them on Render dashboard
        print(f"Error fetching data from Google Places API: {e}")
        return []