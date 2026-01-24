import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../services/auth_service.dart'; // Adjust path to your AuthService
import '../../profile_setting/profile_screen.dart';
import '../../scan/screens/scan_screen.dart'; // Adjust path to ProfileScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Theme Colors
  final Color _bgGreen = const Color(0xFF537A68);
  final Color _lightGreenCard = const Color(0xFFE8F1ED);
  final Color _accentColor = const Color(0xFFD67D76);
  final Color _textColor = const Color(0xFF2C3E36);

  // 1. Services & State
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  String _userName = "Recycler"; // Default name
  String? _profilePicUrl; // Cloudinary URL
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // 2. Fetch User Data Logic
  Future<void> _fetchUserData() async {
    final userData = await _authService.getUserProfile();

    if (mounted) {
      setState(() {
        if (userData != null) {
          // Check if name is not null/empty
          _userName = (userData['name'] != null && userData['name'].isNotEmpty)
              ? userData['name']
              : "Recycler";
          _profilePicUrl = userData['profilePic'];
        }
        _isLoadingUser = false;
      });
    }
  }

  // 3. Navigation with Refresh
  // We use 'await' so code pauses here until the user comes back from Profile
  Future<void> _navigateToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
    // Refresh data immediately upon return
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
              // 5. Dynamic Name with Skeleton Loader
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
            // 6. Avatar Tap Handler
            child: GestureDetector(
              onTap: _navigateToProfile,
              child: CircleAvatar(
                backgroundColor: _lightGreenCard,
                // Display Cloudinary Image if available
                backgroundImage:
                    (_profilePicUrl != null && _profilePicUrl!.isNotEmpty)
                    ? NetworkImage(_profilePicUrl!)
                    : null,
                // Fallback to Icon if no image
                child: (_profilePicUrl == null || _profilePicUrl!.isEmpty)
                    ? Icon(Icons.person, color: _bgGreen)
                    : null,
              ),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
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

                        // Camera Button
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

            // Recent Batches
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
                Text(
                  "See all",
                  style: TextStyle(
                    fontSize: 14,
                    color: _accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildBatchTile(
              time: "10:30 AM",
              title: "Batch #402",
              status: "Processing...",
              isCompleted: false,
            ),
            const SizedBox(height: 12),
            _buildBatchTile(
              time: "09:15 AM",
              title: "Batch #401",
              status: "Completed (98% PET)",
              isCompleted: true,
            ),

            const SizedBox(height: 30),

            // Quick Stats
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
                  value: "1,240",
                  label: "Bottles",
                  color: const Color(0xFFFBE4E4),
                  iconColor: _accentColor,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  icon: Icons.check_circle_outline,
                  value: "85%",
                  label: "Quality A",
                  color: const Color(0xFFE8F1ED),
                  iconColor: _bgGreen,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  icon: Icons.scale,
                  value: "45kg",
                  label: "Total Wt.",
                  color: const Color(0xFFFFF4DE),
                  iconColor: Colors.orange,
                ),
              ],
            ),
          ],
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
