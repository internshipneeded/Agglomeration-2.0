import 'package:flutter/material.dart';

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
  final Color _cardBg = const Color(0xFFF7F9F8); // Very light grey-green

  List<Scan> _scans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchScans();
  }

  Future<void> _fetchScans() async {
    // TODO: Replace with your actual backend URL
    // final url = Uri.parse('https://pet-perplexity.onrender.com/api/scans');
    // final storage = const FlutterSecureStorage();
    // final token = await storage.read(key: 'jwt_token');

    // try {
    // final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    // if (response.statusCode == 200) {
    //   final List<dynamic> data = jsonDecode(response.body);
    //   setState(() {
    //     _scans = data.map((json) => Scan.fromJson(json)).toList();
    //     _isLoading = false;
    //   });
    // }
    // } catch (e) { ... }

    // --- MOCK DATA FOR DEMO (Remove this when API is ready) ---
    await Future.delayed(const Duration(seconds: 1)); // Simulate delay
    if (mounted) {
      setState(() {
        _scans = [
          Scan(
            id: '1',
            imageUrl: 'https://via.placeholder.com/150',
            // Replace with real URL
            timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
            batchId: 'Batch #405',
            totalBottles: 12,
            totalValue: 60.50,
            detections: [],
          ),
          Scan(
            id: '2',
            imageUrl: 'https://via.placeholder.com/150',
            timestamp: DateTime.now().subtract(const Duration(hours: 4)),
            batchId: 'Batch #404',
            totalBottles: 8,
            totalValue: 32.00,
            detections: [],
          ),
          Scan(
            id: '3',
            imageUrl: 'https://via.placeholder.com/150',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
            batchId: 'Batch #403',
            totalBottles: 45,
            totalValue: 210.00,
            detections: [],
          ),
        ];
        _isLoading = false;
      });
    }
    // ---------------------------------------------------------
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Scan History",
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _bgGreen))
          : _scans.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _scans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final scan = _scans[index];
                return _buildScanCard(scan);
              },
            ),
    );
  }

  Widget _buildScanCard(Scan scan) {
    // Format Date: "Jan 24, 10:30 AM"
    final dateStr =
        "${scan.timestamp.day}/${scan.timestamp.month} • ${scan.timestamp.hour}:${scan.timestamp.minute.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                      scan.batchId,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    Text(
                      dateStr,
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
                      label: "${scan.totalBottles} Units",
                      color: _bgGreen,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      icon: Icons.currency_rupee, // Or your currency
                      label: scan.totalValue.toStringAsFixed(1),
                      color: _accentColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for the small chips (Units / Value)
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
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
