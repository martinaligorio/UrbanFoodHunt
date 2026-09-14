// my_reviews_screen.dart
// Manages the user's personal reviews screen for the Urban Food Hunt application.
// Allows users to view, edit, and delete their posted reviews.

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
    File? newImageFile;

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
                    Center(
                      child: newImageFile != null
                          ? Image.file(newImageFile!, height: 80, width: 80, fit: BoxFit.cover)
                          : review['image_url'] != null
                            ? Image.network(
                                review['image_url'].startsWith('http') 
                                    ? review['image_url'] 
                                    : '${widget.backendUrl}${review['image_url']}',
                                height: 80, 
                                width: 80, 
                                fit: BoxFit.cover,
                              )
                            : const Text('No photo', style: TextStyle(color: Colors.grey)),  
                          ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                        if (image != null) {
                          setStateDialog(() {
                            newImageFile = File(image.path);
                          });
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Change Photo'),
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
                    await _updateReviewOnBackend(review['id'], currentRating, commentController.text, newImageFile);
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

  Future<void> _updateReviewOnBackend(int reviewId, int rating, String comment, File? imageFile) async {
    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('${widget.backendUrl}/reviews/$reviewId'),
    );

    request.fields['rating'] = rating.toString();
    request.fields['comment'] = comment;

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
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
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 2,
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
                                        // Pulsante Modifica (Matita Blu)
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          tooltip: 'Edit review',
                                          onPressed: () => _showEditReviewDialog(review),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                        const SizedBox(width: 4),
                                        // Pulsante Elimina (Cestino Rosso)
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
                                if (review['image_url'] != null) ...[
                                  const SizedBox(height: 10),
                                  Builder(
                                    builder: (context) {
                                      String rawUrl = review['image_url'];
                                      String finalImageUrl = rawUrl.startsWith('http') 
                                          ? rawUrl 
                                          : '${widget.backendUrl}$rawUrl';

                                      return Image.network(
                                        finalImageUrl,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Text('Image unavailable'),
                                      );
                                    },
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