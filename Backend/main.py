import math
import httpx
from fastapi import FastAPI, HTTPException

app = FastAPI()

# Replace with your Yelp Fusion API Key
YELP_API_KEY = "QGh5a62SpWUXrXsO7BxGGvt6LvM9CDw8p3OLJSThY0qXXJppqNmydFaP7mgMTj8GmAAm9r9dRylNMJghruF6epmrcY7by0HFdSnlq_dGVJ90aIwz0U1k4JvnivqWanYx"

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