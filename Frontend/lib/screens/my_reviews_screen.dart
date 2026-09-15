// my_reviews_screen.dart
// Manages the user's personal reviews screen for the Urban Food Hunt application.
// Allows users to view, edit, and delete their posted reviews supporting multiple images.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MyReviewsScreen extends StatefulWidget {
  final int userId;
  final String backendUrl;

  const MyReviewsScreen({super.key, required this.userId, required this.backendUrl});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  List<dynamic> _myReviews = [];
  bool _isLoading = true;
  String _errorMessage = "";
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchMyReviews();
  }

  Future<void> _fetchMyReviews() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.backendUrl}/users/${widget.userId}/reviews'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _myReviews = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load your reviews.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteReview(int reviewId) async {
    try {
      final response = await http.delete(
        Uri.parse('${widget.backendUrl}/reviews/$reviewId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _myReviews.removeWhere((review) => review['id'] == reviewId);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review deleted successfully!')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete review.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showEditReviewDialog(Map<String, dynamic> review) {
    final TextEditingController commentController = TextEditingController(text: review['comment'] ?? '');
    int currentRating = review['rating'] ?? 5;
    List<File> newImageFiles = [];

    // Parse existing image URLs safely
    List<String> existingImageUrls = (review['image_url'] != null && review['image_url'].toString().isNotEmpty)
        ? review['image_url'].toString().split(',').map((u) => u.trim()).where((u) => u.isNotEmpty).toList()
        : [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Edit Review for ${review['spot_name']}'),
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
                            star <= currentRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              currentRating = star;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        labelText: 'Edit comment...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 15),
                    const Text('Photos:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    existingImageUrls.isEmpty && newImageFiles.isEmpty
                        ? const Text('No photos', style: TextStyle(color: Colors.grey))
                        : SizedBox(
                            height: 80,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ...existingImageUrls.map((url) {
                                    String finalUrl = url.startsWith('http') ? url : '${widget.backendUrl}$url';
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(finalUrl, height: 80, width: 80, fit: BoxFit.cover),
                                      ),
                                    );
                                  }),
                                  ...newImageFiles.asMap().entries.map((entry) {
                                    int imgIndex = entry.key;
                                    File file = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.file(file, height: 80, width: 80, fit: BoxFit.cover),
                                          ),
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: GestureDetector(
                                              onTap: () {
                                                setStateDialog(() {
                                                  newImageFiles.removeAt(imgIndex);
                                                });
                                              },
                                              child: Container(
                                                color: Colors.black54,
                                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                            if (photo != null) {
                              setStateDialog(() {
                                newImageFiles.add(File(photo.path));
                              });
                            }
                          },
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange, 
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final List<XFile> images = await _picker.pickMultiImage();
                            if (images.isNotEmpty) {
                              setStateDialog(() {
                                newImageFiles.addAll(images.map((img) => File(img.path)));
                              });
                            }
                          },
                          icon: const Icon(Icons.photo_library, size: 16),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange, 
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
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
                    await _updateReviewOnBackend(review['id'], currentRating, commentController.text, newImageFiles);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateReviewOnBackend(int reviewId, int rating, String comment, List<File> imageFiles) async {
    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('${widget.backendUrl}/reviews/$reviewId'),
    );

    request.fields['rating'] = rating.toString();
    request.fields['comment'] = comment;

    for (var file in imageFiles) {
      request.files.add(
        await http.MultipartFile.fromPath('files', file.path),
      );
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final updatedData = json.decode(response.body);
        setState(() {
          int index = _myReviews.indexWhere((r) => r['id'] == reviewId);
          if (index != -1) {
            _myReviews[index] = updatedData;
          }
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review updated successfully!')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update review.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reviews'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _myReviews.isEmpty
                  ? const Center(child: Text('You have not posted any reviews yet.'))
                  : ListView.builder(
                      itemCount: _myReviews.length,
                      itemBuilder: (context, index) {
                        final review = _myReviews[index];
                        
                        List<String> imageUrls = (review['image_url'] != null && review['image_url'].toString().isNotEmpty)
                            ? review['image_url'].toString().split(',').map((u) => u.trim()).where((u) => u.isNotEmpty).toList()
                            : [];

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        review['spot_name'] ?? 'Restaurant Review',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        ...List.generate(
                                          review['rating'] ?? 5,
                                          (index) => const Icon(Icons.star, color: Colors.amber, size: 16),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          tooltip: 'Edit review',
                                          onPressed: () => _showEditReviewDialog(review),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          tooltip: 'Delete review',
                                          onPressed: () => _deleteReview(review['id']),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(review['comment'] ?? 'No comment provided.'),
                                if (imageUrls.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 120,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: imageUrls.length,
                                      itemBuilder: (context, imgIndex) {
                                        String rawUrl = imageUrls[imgIndex];
                                        String finalImageUrl = rawUrl.startsWith('http') 
                                            ? rawUrl 
                                            : '${widget.backendUrl}$rawUrl';

                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              finalImageUrl,
                                              height: 120,
                                              width: 120,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                height: 120,
                                                width: 120,
                                                color: Colors.grey[300],
                                                child: const Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.broken_image, color: Colors.grey, size: 30),
                                                    Text('Failed', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}