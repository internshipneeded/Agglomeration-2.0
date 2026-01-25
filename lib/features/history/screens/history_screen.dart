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
  List<List<Scan>> _groupedBatches = []; // List of Batches
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchScans();
  }

  Future<void> _fetchScans() async {
    const String baseUrl =
        'https://pet-perplexity.onrender.com/api/scan/history';

    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        setState(() {
          _errorMessage = "No token found.";
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Scan> allScans = data.map((json) => Scan.fromJson(json)).toList();

        // --- GROUPING LOGIC ---
        Map<String, List<Scan>> groups = {};
        for (var scan in allScans) {
          if (!groups.containsKey(scan.batchId)) {
            groups[scan.batchId] = [];
          }
          groups[scan.batchId]!.add(scan);
        }

        List<List<Scan>> batches = groups.values.toList();
        // Sort batches by latest date
        batches.sort((a, b) => b.first.timestamp.compareTo(a.first.timestamp));

        setState(() {
          _groupedBatches = batches;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        if (mounted) {
          await _storage.delete(key: 'jwt_token');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = "Error ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error";
        _isLoading = false;
      });
    }
  }

  String _getBatchTitle(Scan scan) {
    if (scan.batchId == 'Unknown Batch' || scan.batchId.isEmpty) {
      return "Scan ${DateFormat('MM/dd').format(scan.timestamp)}";
    }
    String clean = scan.batchId.replaceAll('batch_', '');
    if (clean.length > 8) return "Batch #${clean.substring(clean.length - 6)}";
    return "Batch #$clean";
  }

  // Calculate Avg Purity for the whole batch
  String _getBatchPurity(List<Scan> batch) {
    int totalPet = 0;
    int totalItems = 0;

    for (var scan in batch) {
      // Just check PetClassifier detections
      var petDetections = scan.detections
          .where((d) => d.source == 'PetClassifier')
          .toList();
      totalItems += petDetections.length;
      totalPet += petDetections
          .where((d) => d.material.toUpperCase() == 'PET')
          .length;
    }

    if (totalItems == 0) return "N/A";
    double purity = (totalPet / totalItems) * 100;
    return "${purity.toStringAsFixed(0)}% Pure";
  }

  // Map Batch List to ResultScreen format
  List<Map<String, dynamic>> _batchToResults(List<Scan> batch) {
    return batch
        .map(
          (s) => {
            'imageUrl': s.imageUrl,
            'totalBottles': s.totalBottles,
            'totalValue': s.totalValue,
            'detections': s.detections.map((d) => d.toJson()).toList(),
          },
        )
        .toList();
  }

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
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _groupedBatches.isEmpty
          ? Center(
              child: Text(
                "No scans yet",
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              color: _bgGreen,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _groupedBatches.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildHistoryCard(_groupedBatches[index]);
                },
              ),
            ),
    );
  }

  Widget _buildHistoryCard(List<Scan> batch) {
    // Representative scan (first in list)
    Scan firstScan = batch.first;
    String formattedDate = DateFormat(
      'MMM d, h:mm a',
    ).format(firstScan.timestamp);

    // Aggregates
    int batchTotalItems = batch.fold(0, (sum, item) => sum + item.totalBottles);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(results: _batchToResults(batch)),
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
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: Image.network(
                  firstScan.imageUrl, // Thumbnail of first image
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Icon(
                    Icons.broken_image,
                    color: _bgGreen.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getBatchTitle(firstScan),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatChip(
                        icon: Icons.recycling,
                        label: "$batchTotalItems Items",
                        color: _bgGreen,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        icon: Icons.verified,
                        label: _getBatchPurity(batch),
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
}
