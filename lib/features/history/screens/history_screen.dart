import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../results/screens/result_screen.dart';
import '../../onboarding/auth/screens/login_screen.dart';
import '../models/scan.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Theme Colors
  final Color _bgGreen = const Color(0xFF537A68);
  final Color _accentColor = const Color(0xFFD67D76);
  final Color _textColor = const Color(0xFF2C3E36);
  final Color _cardBg = Colors.white;

  final _storage = const FlutterSecureStorage();
  List<Scan> _scans = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchScans();
  }

  // --- FETCH DATA FROM BACKEND ---
  Future<void> _fetchScans() async {
    // 🔗 Ensure this matches your backend route file
    const String baseUrl = 'https://pet-perplexity.onrender.com/api/scan/history';

    try {
      // 1. FIX: Use 'jwt_token' to match AuthService
      String? token = await _storage.read(key: 'jwt_token');

      if (token == null) {
        setState(() {
          _errorMessage = "No authentication token found. Please login.";
          _isLoading = false;
        });
        return;
      }

      // 2. Send Request with Authorization Header
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Standard JWT header format
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _scans = data.map((json) => Scan.fromJson(json)).toList();
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Session expired. Please login again.")),
          );
          // Redirect to login and remove invalid token
          await _storage.delete(key: 'jwt_token');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = "Failed to load history (${response.statusCode})";
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

  // --- REFRESH FUNCTION ---
  Future<void> _handleRefresh() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _fetchScans();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: Text(
          "Scan History",
          style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _bgGreen))
          : _errorMessage != null
          ? _buildErrorState()
          : _scans.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _handleRefresh,
        color: _bgGreen,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _scans.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildHistoryCard(_scans[index]);
          },
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Scan scan) {
    String formattedDate = "";
    try {
      formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(scan.timestamp);
    } catch (e) {
      formattedDate = "Date Unknown";
    }

    // Shorten Batch ID if it's too long
    String displayBatchId = scan.batchId.length > 10
        ? "Batch #${scan.batchId.substring(scan.batchId.length - 6)}"
        : scan.batchId;

    return GestureDetector(
      onTap: () {
        // Navigate to ResultScreen with the data from this scan object
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(results: scan.toResultList()),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // 1. Image Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: Image.network(
                  scan.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.broken_image, color: _bgGreen.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // 2. Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Batch ID and Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayBatchId,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      Text(
                        formattedDate, // Use formatted date here
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Stats Row (Bottles & Value)
                  Row(
                    children: [
                      _buildStatChip(
                        icon: Icons.recycling,
                        label: "${scan.totalBottles} Items",
                        color: _bgGreen,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        icon: Icons.currency_rupee,
                        label: scan.totalValue.toStringAsFixed(1),
                        color: _accentColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Arrow
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No scans yet",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            "Start scanning to see your history here.",
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              "Something went wrong",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? "Unknown Error",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: _bgGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}
