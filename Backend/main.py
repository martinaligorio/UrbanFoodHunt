import math
import httpx
from fastapi import FastAPI, HTTPException

app = FastAPI()

# Helper function to calculate distance using the Haversine formula
def calculate_haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great-circle distance between two points 
    on the Earth specified in latitude and longitude (returns distance in kilometers).
    """
    earth_radius_km = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    
    c = 2 * math.asin(math.sqrt(a))
    return earth_radius_km * c

# --- NEARBY SPOTS ENDPOINT WITH DISTANCE SORTING (Requirement 1 & 5) ---
@app.get("/spots/nearby")
async def get_nearby_spots(lat: float, lon: float):
    """
    Fetch nearby food spots from OpenStreetMap Overpass API, 
    calculate the distance from user GPS using Haversine formula, 
    sort them by distance in ascending order, and return the results.
    """
    overpass_url = "https://overpass-api.de/api/interpreter"
    
    # Search bounding box offset (approx 5-10km radius)
    delta = 0.01
    south = lat - delta
    north = lat + delta
    west = lon - delta
    east = lon + delta
    
    overpass_query = f"""
    [out:json][timeout:10];
    (
      node["amenity"~"restaurant|fast_food|cafe"]({south},{west},{north},{east});
    );
    out body;
    """
    
    headers = {"User-Agent": "UrbanFoodHuntApp/1.0"}

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(overpass_url, data=overpass_query, headers=headers)
            
            if response.status_code != 200:
                return []
                
            data = response.json()
            elements = data.get("elements", [])
            
            spots = []
            for element in elements:
                tags = element.get("tags", {})
                if "name" in tags and "lat" in element and "lon" in element:
                    spot_lat = element.get("lat")
                    spot_lon = element.get("lon")
                    
                    # Compute distance in kilometers from client GPS coordinates
                    distance = calculate_haversine_distance(lat, lon, spot_lat, spot_lon)
                    
                    spots.append({
                        "id": element.get("id"),
                        "name": tags.get("name"),
                        "address": tags.get("addr:street", "Address not specified"),
                        "latitude": spot_lat,
                        "longitude": spot_lon,
                        "distance_km": round(distance, 2)  # Rounded distance for UI
                    })
            
            # Sort spots by distance ascending (closest first)
            spots.sort(key=lambda x: x["distance_km"])
            
            # Return up to 15 closest spots
            return spots[:15]

    except Exception as e:
        print(f"Error fetching data from public cloud API: {e}")
        return []