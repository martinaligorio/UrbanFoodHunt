import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:geolocator/geolocator.dart'; // Required for GPS tracking (Requirement 5)
import 'package:sensors_plus/sensors_plus.dart'; // Required for accelerometer sensor (Requirement 4)
import 'package:fl_chart/fl_chart.dart'; // Required for 2D graphics (Requirement 3)
import 'package:image_picker/image_picker.dart'; // Required for camera integration (Requirement 6)
import 'my_reviews_screen.dart';

class HomeScreen extends StatefulWidget {
  final int? userId;
  final String? username;

  const HomeScreen({super.key, this.userId, this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Remote backend URL configuration (Requirement 9: Remote REST API)
  final String backendUrl = "https://urbanfoodhunt.onrender.com";
  String _serverStatus = "Not connected";
  List<dynamic> _spotsList = [];
  bool _isLoading = false;

  // State variable for maximum distance selected by user via Slider (default 5 km)
  double _maxDistanceKm = 5.0;

  // State variables for GPS location management (Requirement 5: GPS)
  String _locationMessage = "Location not yet detected";
  bool _isGettingLocation = false;

  // State variables for Accelerometer Sensor (Requirement 4: Sensors)
  String _sensorMessage = "Shake your phone to discover a random spot!";
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isShaking = false;

  // State variables for Camera / Image Picker (Requirement 6: Camera & Image Processing)
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _startListeningToSensor();
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  /// Sorts the loaded spots list based on user-selected criteria (distance, rating, or reviews)
  void _sortSpots(String criteria) {
    setState(() {
      if (criteria == 'distance') {
        _spotsList.sort((a, b) => (a['distance_km'] ?? 0.0).compareTo(b['distance_km'] ?? 0.0));
      } else if (criteria == 'rating') {
        _spotsList.sort((a, b) => (b['rating'] ?? 0.0).compareTo(a['rating'] ?? 0.0));
      } else if (criteria == 'reviews') {
        _spotsList.sort((a, b) => (b['review_count'] ?? 0).compareTo(a['review_count'] ?? 0));
      }
    });
  }

  /// Displays an interactive review dialog allowing star rating selection, comments, 
  /// and native camera photo capture (Requirement 6)
  void _showAddReviewDialog(BuildContext context, String spotId, String spotName) {
    final TextEditingController commentController = TextEditingController();
    int selectedRating = 5;
    File? dialogImage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Review $spotName'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rating (1-5 stars):'),
                    Row(
                      children: List.generate(5, (index) {
                        int star = index + 1;
                        return IconButton(
                          icon: Icon(
                            star <= selectedRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              selectedRating = star;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        labelText: 'Write a comment...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 15),
                    Center(
                      child: dialogImage != null
                          ? Image.file(dialogImage!, height: 100, width: 100, fit: BoxFit.cover)
                          : const Text('No photo attached', style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                        if (image != null) {
                          setStateDialog(() {
                            dialogImage = File(image.path);
                          });
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo (Camera)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _submitReviewCustom(spotId, spotName, selectedRating, commentController.text, dialogImage);
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Asynchronously submits a review with multipart form data (image + text) to the remote backend (Requirement 7 & 9)
  Future<void> _submitReviewCustom(String spotId, String spotName, int rating, String comment, File? imageFile) async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to post a review!')),
      );
      return;
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendUrl/spots/$spotId/reviews'),
    );

    request.fields['rating'] = rating.toString();
    request.fields['comment'] = comment;
    request.fields['user_id'] = widget.userId.toString();
    request.fields['spot_name'] = spotName;

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
    }

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review for $spotName added successfully!')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit review.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  /// Opens a modal bottom sheet displaying an interactive 2D Bar Chart of restaurant ratings (Requirement 3: 2D Graphics)
  void _showRatingChartModal(BuildContext context) {
    if (_spotsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No spots loaded yet. Please search via GPS first!')),
      );
      return;
    }

    Map<double, int> ratingCounts = {
      3.0: 0,
      3.5: 0,
      4.0: 0,
      4.5: 0,
      5.0: 0,
    };

    for (var spot in _spotsList) {
      double rating = (spot['rating'] ?? 0.0).toDouble();
      double bucket = (rating * 2).round() / 2;
      if (ratingCounts.containsKey(bucket)) {
        ratingCounts[bucket] = ratingCounts[bucket]! + 1;
      } else {
        if (bucket < 3.0) {
          ratingCounts[3.0] = (ratingCounts[3.0] ?? 0) + 1;
        } else {
          ratingCounts[5.0] = (ratingCounts[5.0] ?? 0) + 1;
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ratings Distribution (2D Chart)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              const Text(
                'Number of nearby spots per star rating',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 25),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 15,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
                            String text = '';
                            switch (value.toInt()) {
                              case 0: text = '3.0 ⭐'; break;
                              case 1: text = '3.5 ⭐'; break;
                              case 2: text = '4.0 ⭐'; break;
                              case 3: text = '4.5 ⭐'; break;
                              case 4: text = '5.0 ⭐'; break;
                            }
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(text, style: style),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: ratingCounts[3.0]!.toDouble(), color: Colors.orange, width: 18, borderRadius: BorderRadius.circular(4))]),
                      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: ratingCounts[3.5]!.toDouble(), color: Colors.orange, width: 18, borderRadius: BorderRadius.circular(4))]),
                      BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: ratingCounts[4.0]!.toDouble(), color: Colors.deepOrange, width: 18, borderRadius: BorderRadius.circular(4))]),
                      BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: ratingCounts[4.5]!.toDouble(), color: Colors.deepOrange, width: 18, borderRadius: BorderRadius.circular(4))]),
                      BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: ratingCounts[5.0]!.toDouble(), color: Colors.amber, width: 18, borderRadius: BorderRadius.circular(4))]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Navigates to the user reviews management screen
  void _navigateToMyReviews() {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to view your reviews!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyReviewsScreen(userId: widget.userId!, backendUrl: backendUrl),
      ),
    );
  }

  /// Asynchronously acquires device GPS coordinates and fetches nearby spots from the cloud server (Requirement 5, 7, & 9)
  Future<void> _getCurrentLocationAndFetchSpots() async {
    setState(() {
      _isGettingLocation = true;
      _locationMessage = "Acquiring GPS and contacting cloud server...";
    });

    bool serviceEnabled;
    LocationPermission permission;

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
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _locationMessage = "Lat: ${position.latitude}, Lon: ${position.longitude}";
        _serverStatus = "Contacting Render backend (cold start active)...";
      });

      final url = Uri.parse('$backendUrl/spots/nearby?lat=${position.latitude}&lon=${position.longitude}&radius_km=$_maxDistanceKm');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 45),
        onTimeout: () => http.Response('{"error": "timeout"}', 408),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _spotsList = data;
          _serverStatus = "Found ${_spotsList.length} spots within ${_maxDistanceKm.toStringAsFixed(1)} km!";
        });
      } else {
        setState(() {
          _serverStatus = "Server warming up or failed to load. Please retry.";
        });
      }
    } catch (e) {
      setState(() {
        _locationMessage = "Error: $e";
        _serverStatus = "Connection error during remote fetch.";
      });
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  /// Listens to the device accelerometer sensor to detect shake gestures (Requirement 4: Sensors)
  void _startListeningToSensor() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      if (acceleration > 15 && !_isShaking) {
        _isShaking = true;
        _triggerRandomFoodHunt();
        
        Timer(const Duration(seconds: 2), () {
          _isShaking = false;
        });
      }
    });
  }

  /// Triggers a random food spot recommendation when the phone is shaken
  void _triggerRandomFoodHunt() {
    if (_spotsList.isEmpty) {
      setState(() {
        _sensorMessage = "🎉 Shake detected!\nNo nearby spots loaded yet. Please search via GPS first!";
      });
      return;
    }
    
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
        title: Text(widget.username != null ? 'Urban Food Hunt (${widget.username})' : 'Urban Food Hunt'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'View My Reviews',
            onPressed: _navigateToMyReviews,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Maximum Distance:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        '${_maxDistanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 15),
                      ),
                    ],
                  ),
                  Slider(
                    value: _maxDistanceKm,
                    min: 1.0,
                    max: 30.0,
                    divisions: 29,
                    activeColor: Colors.deepOrange,
                    inactiveColor: Colors.orange[100],
                    label: '${_maxDistanceKm.toStringAsFixed(1)} km',
                    onChanged: (double value) {
                      setState(() {
                        _maxDistanceKm = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _isGettingLocation
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _getCurrentLocationAndFetchSpots,
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Find Nearby Spots (GPS)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
            const SizedBox(height: 15),
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
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () => _showRatingChartModal(context),
              icon: const Icon(Icons.bar_chart),
              label: const Text('View Ratings 2D Chart'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[800],
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Food Spots:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_spotsList.isNotEmpty)
                  Text(
                    '${_spotsList.length} found',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.near_me, size: 16, color: Colors.orange),
                    label: const Text('Sort by Distance'),
                    onPressed: () => _sortSpots('distance'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
                    label: const Text('Top Rating'),
                    onPressed: () => _sortSpots('rating'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.comment, size: 16, color: Colors.blue),
                    label: const Text('Most Reviewed'),
                    onPressed: () => _sortSpots('reviews'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _spotsList.isEmpty
                  ? const Center(child: Text("Adjust the slider and tap 'Find Nearby Spots' to start."))
                  : ListView.builder(
                      itemCount: _spotsList.length,
                      itemBuilder: (context, index) {
                        final spot = _spotsList[index];
                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTile(
                              leading: spot['image_url'] != null && spot['image_url'].toString().isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          spot['image_url'],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                                            backgroundColor: Colors.orangeAccent,
                                            child: Icon(Icons.storefront, color: Colors.white),
                                          ),
                                        ),
                                      )
                                  : const CircleAvatar(
                                    backgroundColor: Colors.orangeAccent,
                                    child: Icon(Icons.storefront, color: Colors.white),
                                  ),
                              title: Text(
                                spot['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    spot['address'] ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          "${spot['rating'] ?? 0.0} (${spot['review_count'] ?? 0} reviews) • ${spot['distance_km'] ?? 0.0} km",
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton.icon(
                                onPressed: () => _showAddReviewDialog(context, spot['id'].toString(), spot['name']),
                                icon: const Icon(Icons.rate_review, size: 16),
                                label: const Text('Review'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
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