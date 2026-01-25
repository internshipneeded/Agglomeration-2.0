import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../../services/auth_service.dart';
import '../../history/models/detection.dart';
import '../../history/models/scan.dart';
import '../../history/screens/history_screen.dart';
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

  // --- Services & State ---
  final AuthService _authService = AuthService();
  final _storage = const FlutterSecureStorage();

  // User Data
  String _userName = "Recycler";
  String? _profilePicUrl;
  bool _isLoadingUser = true;

  // Dashboard Data
  bool _isLoadingData = true;
  List<Scan> _recentScans = [];
  int _statsTotalBottles = 0;
  double _statsAvgQuality = 0.0; // % Clear PET
  double _statsContamination = 0.0; // % Non-PET

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([_fetchUserData(), _fetchDashboardData()]);
  }

  // 1. Fetch User Profile
  Future<void> _fetchUserData() async {
    final userData = await _authService.getUserProfile();
    if (mounted) {
      setState(() {
        if (userData != null) {
          _userName = (userData['name'] != null && userData['name'].isNotEmpty)
              ? userData['name']
              : "Recycler";
          _profilePicUrl = userData['profilePic'];
        }
        _isLoadingUser = false;
      });
    }
  }

  // 2. Fetch Scan History & Calculate Stats
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

        // Calculate Stats
        _calculateStats(allScans);

        // Take top 2 recent scans
        if (mounted) {
          setState(() {
            _recentScans = allScans.take(2).toList();
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  void _calculateStats(List<Scan> scans) {
    int totalBottles = 0;
    int totalItemsAnalyzed = 0;
    int totalClearPet = 0;
    int totalNonPet = 0;

    for (var scan in scans) {
      totalBottles += scan.totalBottles;

      // Find representative detection for material/color
      var materialDet = scan.detections.firstWhere(
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

      // Fallback
      if (materialDet.source == 'Unknown') {
        materialDet = scan.detections.firstWhere(
          (d) => d.source == 'Agglo_2.0',
          orElse: () => materialDet,
        );
      }

      // Count Logic
      if (materialDet.material.toUpperCase() == 'PET') {
        totalItemsAnalyzed++;
        if (materialDet.color.toLowerCase().contains('clear') ||
            materialDet.color.toLowerCase().contains('transparent')) {
          totalClearPet++;
        }
      } else if (materialDet.material != 'Unknown') {
        totalItemsAnalyzed++;
        totalNonPet++;
      }
    }

    _statsTotalBottles = totalBottles;

    // Calculate Percentages
    if (totalItemsAnalyzed > 0) {
      _statsAvgQuality = (totalClearPet / totalItemsAnalyzed) * 100;
      _statsContamination = (totalNonPet / totalItemsAnalyzed) * 100;
    } else {
      _statsAvgQuality = 0.0;
      _statsContamination = 0.0;
    }
  }

  // --- SMART NAMING HELPER ---
  String _getBatchTitle(Scan scan) {
    if (scan.batchId == 'Unknown Batch' || scan.batchId.isEmpty) {
      return "Scan ${DateFormat('MM/dd').format(scan.timestamp)}";
    }

    String cleanId = scan.batchId.replaceAll('batch_', '');
    if (cleanId.length > 6) {
      return "Batch #${cleanId.substring(cleanId.length - 6)}";
    }
    return "Batch #$cleanId";
  }

  Future<void> _navigateToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
    _fetchUserData();
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
                  ? Container(
                      width: 120,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
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
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: GestureDetector(
              onTap: _navigateToProfile,
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
              // --- HERO SECTION ---
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
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ScanScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
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
                    const SizedBox(width: 10),
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoryScreen(),
                      ),
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
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          "No scans yet. Start your first scan!",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    )
                  : Column(
                      children: _recentScans.map((scan) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildBatchTile(
                            time: DateFormat('h:mm a').format(scan.timestamp),
                            title: _getBatchTitle(scan),
                            status: "${scan.totalBottles} Items Processed",
                            // Removed Revenue
                            isCompleted: true,
                          ),
                        );
                      }).toList(),
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
                    icon: Icons.recycling,
                    value: _isLoadingData ? "-" : "$_statsTotalBottles",
                    label: "Bottles",
                    color: const Color(0xFFFBE4E4),
                    iconColor: _accentColor,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    icon: Icons.check_circle_outline,
                    value: _isLoadingData
                        ? "-"
                        : "${_statsAvgQuality.toStringAsFixed(0)}%",
                    label: "Quality",
                    color: const Color(0xFFE8F1ED),
                    iconColor: _bgGreen,
                  ),
                  const SizedBox(width: 16),
                  // New Metric: Contamination
                  _buildStatCard(
                    icon: Icons.warning_amber_rounded,
                    value: _isLoadingData
                        ? "-"
                        : "${_statsContamination.toStringAsFixed(0)}%",
                    label: "Contamination",
                    color: const Color(0xFFFFF4DE),
                    iconColor: Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers
  Widget _buildBatchTile({
    required String time,
    required String title,
    required String status,
    required bool isCompleted,
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
                  status,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isCompleted ? Icons.check_circle : Icons.sync,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
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
