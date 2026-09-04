import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _fetchMyReviews();
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
                                        const SizedBox(width: 8),
                                        // Pulsante Elimina (Cestino)
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
                                  Image.network(
                                    '${widget.backendUrl}${review['image_url']}',
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Text('Image unavailable'),
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