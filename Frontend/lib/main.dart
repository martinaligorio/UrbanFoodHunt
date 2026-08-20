import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart'; // Required for GPS tracking (Requirement 5)

/// Main entry point of the Flutter application.
void main() {
  runApp(const UrbanFoodHuntApp());
}

class UrbanFoodHuntApp extends StatelessWidget {
  const UrbanFoodHuntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban Food Hunt',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Backend URL configuration (Requirement 9)
  // Note: Use 'http://10.0.2.2:8000' for Android Emulator
  final String backendUrl = "http://10.0.2.2:8000";
  
  String _serverStatus = "Not connected";
  List<dynamic> _spotsList = [];
  bool _isLoading = false;

  // State variables for GPS location management (Requirement 5)
  String _locationMessage = "Location not yet detected";
  bool _isGettingLocation = false;

  /// Asynchronous function to test local backend connection (Concurrency & REST API)
  Future<void> _checkServerConnection() async {
    setState(() {
      _isLoading = true;
      _serverStatus = "Connecting to local backend...";
    });

    try {
      final response = await http.get(Uri.parse('$backendUrl/'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _serverStatus = "Connected! Server says:\n${data['message']}";
        });
        // Fetch food spots after successful connection
        _fetchFoodSpots();
      } else {
        setState(() {
          _serverStatus = "Server error: Status code ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _serverStatus = "Connection failed: $e\nMake sure Uvicorn is active!";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Function to retrieve food spots from the local database via REST API (/spots/)
  Future<void> _fetchFoodSpots() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/spots/'));
      if (response.statusCode == 200) {
        setState(() {
          _spotsList = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Error fetching spots: $e");
    }
  }

  /// Function to retrieve current GPS coordinates and query nearby spots from FastAPI backend
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationMessage = "Checking GPS permissions and service status...";
    });

    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location services are enabled on the device
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = "Location services are disabled on the device.";
        _isGettingLocation = false;
      });
      return;
    }

    // 2. Check application location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationMessage = "Location permissions were denied.";
          _isGettingLocation = false;
        });
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationMessage = "Location permissions are permanently denied. Please enable them in settings.";
        _isGettingLocation = false;
      });
      return;
    }

    // 3. Retrieve the current geographic position and query backend
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      setState(() {
        _locationMessage = "Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}\nFetching nearby spots from backend...";
      });

      // Query the FastAPI backend passing the GPS coordinates
      final response = await http.get(
        Uri.parse('$backendUrl/spots/nearby?lat=${position.latitude}&lon=${position.longitude}')
      );

      if (response.statusCode == 200) {
        setState(() {
          _spotsList = jsonDecode(response.body);
          _locationMessage = "Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}\n(Nearby food spots successfully retrieved!)";
        });
      } else {
        setState(() {
          _locationMessage = "Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}\n(GPS acquired, but backend returned status: ${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _locationMessage = "Error while retrieving location or connecting to backend: $e";
      });
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Urban Food Hunt - Local Cloud'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.fastfood,
              size: 80,
              color: Colors.deepOrange,
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to Urban Food Hunt!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Server status display box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _serverStatus,
                style: const TextStyle(fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Server connection test button
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _checkServerConnection,
                    icon: const Icon(Icons.cloud_sync),
                    label: const Text('Test Local Backend Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
            const SizedBox(height: 20),

            // GPS Feature UI Component (Requirement 5)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                _locationMessage,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            _isGettingLocation
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.location_on),
                    label: const Text('Find Nearby Spots (GPS)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
            const SizedBox(height: 20),

            const Text(
              'Food Spots from Local Database:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Dynamic list of food spots retrieved from SQLite database or GPS backend filter
            Expanded(
              child: _spotsList.isEmpty
                  ? const Center(child: Text("No food spots loaded or connection not tested yet."))
                  : ListView.builder(
                      itemCount: _spotsList.length,
                      itemBuilder: (context, index) {
                        final spot = _spotsList[index];
                        return Card(
                          elevation: 2,
                          child: ListTile(
                            leading: const Icon(Icons.storefront, color: Colors.orange),
                            title: Text(spot['name'] ?? ''),
                            // Display both address and calculated distance in kilometers
                            subtitle: Text("${spot['address'] ?? ''} • ${spot['distance_km']} km away"),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}