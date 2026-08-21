import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart'; // Required for GPS tracking (Requirement 5)
import 'package:sensors_plus/sensors_plus.dart'; // Required for accelerometer sensor (Requirement 4)

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
  // Use 'http://10.0.2.2:8000' for Android Emulator or your Render URL for production
  final String backendUrl = "http://10.0.2.2:8000";
  
  String _serverStatus = "Not connected";
  List<dynamic> _spotsList = [];
  bool _isLoading = false;

  // State variables for GPS location management (Requirement 5)
  String _locationMessage = "Location not yet detected";
  bool _isGettingLocation = false;

  // State variables for Accelerometer Sensor (Requirement 4)
  String _sensorMessage = "Shake your phone to discover a random spot!";
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isShaking = false;

  @override
  void initState() {
    super.initState();
    _startListeningToSensor();
  }

  @override
  void dispose() {
    // Cancel sensor stream subscription to prevent memory leaks
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  /// Asynchronous function to test local/remote backend connection (Concurrency & REST API)
  Future<void> _checkServerConnection() async {
    setState(() {
      _isLoading = true;
      _serverStatus = "Connecting to backend...";
    });

    try {
      final response = await http.get(Uri.parse('$backendUrl/'));
      
      if (response.statusCode == 200) {
        setState(() {
          _serverStatus = "Connected successfully! Server is online.";
        });
      } else {
        setState(() {
          _serverStatus = "Server responded with status: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _serverStatus = "Connection failed: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Asynchronous function to handle GPS location acquisition and fetch nearby spots (Requirement 5 & Public Cloud API)
  Future<void> _getCurrentLocationAndFetchSpots() async {
    setState(() {
      _isGettingLocation = true;
      _locationMessage = "Checking location permissions...";
    });

    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = 'Location services are disabled.';
        _isGettingLocation = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationMessage = 'Location permissions are denied.';
          _isGettingLocation = false;
        });
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationMessage = 'Location permissions are permanently denied.';
        _isGettingLocation = false;
      });
      return;
    }

    try {
      // Get current GPS coordinates
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _locationMessage = "Lat: ${position.latitude}, Lon: ${position.longitude}";
      });

      // Fetch nearby spots from backend passing GPS coordinates
      final url = Uri.parse('$backendUrl/spots/nearby?lat=${position.latitude}&lon=${position.longitude}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _spotsList = data;
          _serverStatus = "Found ${_spotsList.length} nearby spots!";
        });
      } else {
        setState(() {
          _serverStatus = "Failed to load spots from backend.";
        });
      }
    } catch (e) {
      setState(() {
        _locationMessage = "Error getting GPS: $e";
      });
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  /// Listen to the accelerometer sensor to detect shake gestures (Requirement 4)
  void _startListeningToSensor() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // Calculate total G-force acceleration vector
      double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Threshold for a shake gesture (earth gravity is ~9.8, a sudden shake exceeds ~15)
      if (acceleration > 15 && !_isShaking) {
        _isShaking = true;
        _triggerRandomFoodHunt();
        
        // Reset shake lock after 2 seconds
        Timer(const Duration(seconds: 2), () {
          _isShaking = false;
        });
      }
    });
  }

  /// Trigger a random food recommendation when shaken, choosing from nearby GPS spots
  void _triggerRandomFoodHunt() {
    // Check if the nearby spots list is empty
    if (_spotsList.isEmpty) {
      setState(() {
        _sensorMessage = "🎉 Shake detected!\nNo nearby spots loaded yet. Please search via GPS first!";
      });
      return;
    }
    
    // Select a random spot from the dynamically fetched nearby spots list
    final randomSpot = _spotsList[Random().nextInt(_spotsList.length)];
    
    final spotName = randomSpot['name'] ?? 'Unknown Spot';
    final spotAddress = randomSpot['address'] ?? 'Address not specified';
    final spotDistance = randomSpot['distance_km'] ?? '';

    setState(() {
      _sensorMessage = "🎉 Shake detected!\nRecommended: $spotName\n📍 $spotAddress • $spotDistance km away";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Urban Food Hunt'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Header
            const Text(
              'Welcome to Urban Food Hunt!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            
            // Server Status Container
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
            const SizedBox(height: 15),

            // Test Connection Button
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _checkServerConnection,
                    icon: const Icon(Icons.cloud_sync),
                    label: const Text('Test Backend Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
            const SizedBox(height: 10),

            // GPS Location Button
            _isGettingLocation
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _getCurrentLocationAndFetchSpots,
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Find Nearby Spots (GPS)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
            const SizedBox(height: 10),

            // Sensor Box (Requirement 4: Accelerometer Shake)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vibration, color: Colors.orange, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _sensorMessage,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // List Header
            const Text(
              'Food Spots Sorted by Distance:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Dynamic list of food spots retrieved from Public Cloud API & GPS calculation
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
                            // Display address and calculated distance in kilometers
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