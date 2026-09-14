# Urban Food Hunt 🍔📍

Welcome to **Urban Food Hunt**, a full-stack mobile application designed to help food lovers discover nearby restaurants, share reviews with photos, and explore local spots using advanced mobile sensors and cloud services. 

---

## 🚀 Key Features & Course Requirements Mapped

Every single requirement for the project has been fully implemented and tested:

1. **Public Cloud Service:** Integrates the **Yelp Fusion API** to fetch real-time restaurant data, ratings, and locations based on geographic coordinates.
2. **Multi-User Authentication:** Complete user registration and login system backed by secure database storage.
3. **2D Graphics:** Features an interactive bar chart built with `fl_chart` to visualize the distribution of restaurant ratings in your area.
4. **Mobile Sensors:** Implements an **accelerometer** listener—shake your phone to instantly trigger a random food spot recommendation!
5. **GPS Integration:** Uses the device's GPS (`geolocator`) to find spots around your exact current location with a customizable distance slider (1–30 km).
6. **Camera & Image Processing:** Allows users to snap photos using the native camera (`image_picker`) and attach them to reviews.
7. **Concurrency:** Fully asynchronous architecture leveraging `async/await` coroutines on both the Flutter frontend and FastAPI backend.
8. **Additional Cloud Feature:** Uses **Cloudinary** for scalable cloud image hosting and optimization, replacing local storage.
9. **Remote REST API:** The backend is fully deployed and running live on **Render**, serving requests over HTTPS.
10. **Storage Service:** Relational SQLite database managed via SQLAlchemy and fully exposed through REST API CRUD endpoints.

---

## 🛠️ Tech Stack

* **Frontend:** Flutter (Dart) — Cross-platform mobile UI.
* **Backend:** Python with FastAPI & SQLAlchemy — High-performance asynchronous REST API.
* **Database:** SQLite — Lightweight relational data storage.
* **Cloud & External APIs:** 
  * *Yelp Fusion API* (Spot discovery)
  * *Cloudinary* (Image storage & management)
  * *Render* (Cloud PaaS hosting for the backend)

---

## 📂 Project Structure

The project is organized as a monorepo containing both the backend service and the mobile client:

```text
UrbanFoodHunt/
│
├── Backend/                 # Python FastAPI server
│   ├── routers/             # Modular API route controllers
│   │   ├── users.py         # User registration and authentication endpoints
│   │   ├── spots.py         # Yelp API integration and nearby spot discovery
│   │   └── reviews.py       # Review CRUD operations and Cloudinary uploads
│   ├── main.py              # Application entry point and router integration
│   ├── models.py            # SQLAlchemy database models (Users, Spots, Reviews)
│   ├── schemas.py           # Pydantic data validation schemas
│   ├── database.py          # Database configuration and session management
│   ├── requirements.txt     # Python backend dependencies
│   └── urbanfoodhunt.db     # SQLite relational database
│
└── Frontend/                # Flutter mobile application
    ├── lib/                 # Dart source code (screens, logic, state management)
    ├── android/             # Android-specific configurations
    ├── ios/                 # iOS-specific configurations
    └── pubspec.yaml         # Flutter dependencies and assets
```

## 🏃‍♂️ Getting Started Locally

If you want to run or test the project locally on your machine, follow these steps:

### 1. Run the Backend
Open a terminal, navigate to the `Backend` folder, set up your environment, and start the server:

```bash
cd Backend
pip install -r requirements.txt
uvicorn main:app --reload
```
2. Run the Flutter App
Open a separate terminal, navigate to the `Frontend` folder, update your backendUrl in main.dart if needed, and launch the application:
```Bash
cd Frontend
flutter pub get
flutter run
```

☁️ Live Backend
The production REST API is hosted on Render and accessible at:
https://urbanfoodhunt.onrender.com 
