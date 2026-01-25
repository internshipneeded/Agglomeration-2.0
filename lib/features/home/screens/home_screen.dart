import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../../services/auth_service.dart';
import '../../history/models/detection.dart';
import '../../history/models/scan.dart';
import '../../history/screens/history_screen.dart'; // Ensure this file exists
import '../../profile_setting/profile_screen.dart';
import '../../scan/screens/scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- Theme Colors ---
  final Color _bgGreen = const Color(0xFF537A68);
  final Color _lightGreenCard = const Color(0xFFE8F1ED);
  final Color _accentColor = const Color(0xFFD67D76);
  final Color _textColor = const Color(0xFF2C3E36);

  // --- Services ---
  final AuthService _authService = AuthService();
  final _storage = const FlutterSecureStorage();

  // --- State ---
  String _userName = "Recycler";
  String? _profilePicUrl;
  bool _isLoadingUser = true;
  bool _isLoadingData = true;

  List<Scan> _recentScans = [];
  int _statsTotalBottles = 0;
  double _statsAvgQuality = 0.0;
  double _statsContamination = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([_fetchUserData(), _fetchDashboardData()]);
  }

  Future<void> _fetchUserData() async {
    final userData = await _authService.getUserProfile();
    if (mounted) {
      setState(() {
        if (userData != null) {
          _userName = (userData['name']?.isNotEmpty ?? false)
              ? userData['name']
              : "Recycler";
          _profilePicUrl = userData['profilePic'];
        }
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _fetchDashboardData() async {
    const String baseUrl =
        'https://pet-perplexity.onrender.com/api/scan/history';

    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return;

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

        // Sort by date (newest first)
        allScans.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        _calculateStats(allScans);

        if (mounted) {
          setState(() {
            _recentScans = allScans.take(2).toList();
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  void _calculateStats(List<Scan> scans) {
    int totalBottles = 0;
    int totalItems = 0;
    int totalClear = 0;
    int totalNonPet = 0;

    for (var scan in scans) {
      totalBottles += scan.totalBottles;

      // Find representative detection
      var det = scan.detections.firstWhere(
        (d) => d.source == 'PetClassifier',
        orElse: () => Detection(
          source: 'Unknown',
          label: '',
          confidence: 0,
          brand: '',
          color: 'Unknown',
          material: 'Unknown',
        ),
      );
      if (det.source == 'Unknown') {
        det = scan.detections.firstWhere(
          (d) => d.source == 'Agglo_2.0',
          orElse: () => det,
        );
      }

      if (det.material.toUpperCase() == 'PET') {
        totalItems++;
        if (det.color.toLowerCase().contains('clear') ||
            det.color.toLowerCase().contains('transparent')) {
          totalClear++;
        }
      } else if (det.material != 'Unknown') {
        totalItems++;
        totalNonPet++;
      }
    }

    _statsTotalBottles = totalBottles;

    if (totalItems > 0) {
      _statsAvgQuality = (totalClear / totalItems) * 100;
      _statsContamination = (totalNonPet / totalItems) * 100;
    }
  }

  String _getBatchTitle(Scan scan) {
    if (scan.batchId == 'Unknown Batch' || scan.batchId.isEmpty) {
      return "Scan ${DateFormat('MM/dd').format(scan.timestamp)}";
    }
    String clean = scan.batchId.replaceAll('batch_', '');
    if (clean.length > 6) return "Batch #${clean.substring(clean.length - 6)}";
    return "Batch #$clean";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _isLoadingUser
                  ? Container(width: 100, height: 20, color: Colors.grey[200])
                  : Text(
                      "Hello, $_userName",
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        fontFamily: 'Poppins',
                      ),
                    ),
              Text(
                "Ready to recycle?",
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: CircleAvatar(
                backgroundColor: _lightGreenCard,
                backgroundImage:
                    (_profilePicUrl != null && _profilePicUrl!.isNotEmpty)
                    ? NetworkImage(_profilePicUrl!)
                    : null,
                child: (_profilePicUrl == null || _profilePicUrl!.isEmpty)
                    ? Icon(Icons.person, color: _bgGreen)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: _bgGreen,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HERO ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _lightGreenCard,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "New Batch Scan",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Identify PET bottles, separate colors, and detect contaminants.",
                            style: TextStyle(
                              fontSize: 13,
                              color: _textColor.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ScanScreen(),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text("Start Scanning"),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.camera_enhance_rounded,
                      size: 80,
                      color: _bgGreen.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- RECENT BATCHES ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Batches",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  GestureDetector(
                    // 🔴 THIS NAVIGATES TO HISTORY LIST
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                    child: Text(
                      "See all",
                      style: TextStyle(
                        fontSize: 14,
                        color: _accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _isLoadingData
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _recentScans.isEmpty
                  ? Center(
                      child: Text(
                        "No scans found.",
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                  : Column(
                      children: _recentScans
                          .map(
                            (scan) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: _buildBatchTile(
                                time: DateFormat(
                                  'h:mm a',
                                ).format(scan.timestamp),
                                title: _getBatchTitle(scan),
                                subtitle:
                                    "${scan.totalBottles} Items Processed",
                              ),
                            ),
                          )
                          .toList(),
                    ),

              const SizedBox(height: 30),

              // --- OVERVIEW STATS ---
              Text(
                "Overview",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatCard(
                    Icons.recycling,
                    "$_statsTotalBottles",
                    "Bottles",
                    const Color(0xFFFBE4E4),
                    _accentColor,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    Icons.verified,
                    "${_statsAvgQuality.toStringAsFixed(0)}%",
                    "Quality",
                    const Color(0xFFE8F1ED),
                    _bgGreen,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    Icons.warning_amber,
                    "${_statsContamination.toStringAsFixed(0)}%",
                    "Non-PET",
                    const Color(0xFFFFF4DE),
                    Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchTile({
    required String time,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _bgGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _bgGreen.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.white, size: 28),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color bg,
    Color iconColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: _textColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
