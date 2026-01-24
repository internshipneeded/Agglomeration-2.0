import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Theme Colors (Matching the Abigail Theme)
  final Color _bgGreen = const Color(0xFF537A68); // Dark Sage
  final Color _lightGreenCard = const Color(0xFFE8F1ED); // Light pastel green for Hero card
  final Color _accentColor = const Color(0xFFD67D76); // Terracotta/Salmon
  final Color _textColor = const Color(0xFF2C3E36);

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background like the inner app screenshot

      // 1. Top App Bar Area
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, Aditya", // Placeholder user
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
            child: CircleAvatar(
              backgroundColor: _lightGreenCard,
              child: Icon(Icons.person, color: _bgGreen),
            ),
          )
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 2. Hero Section (The "Featured Challenge" Card)
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
                            // TODO: Open Camera / Image Picker
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text("Start Camera"),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Decorative Icon/Image
                  Icon(Icons.camera_enhance_rounded, size: 80, color: _bgGreen.withOpacity(0.5)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 3. Recent Batches (The "Today's Tasks" Green Pills)
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

            // List of Recent items
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

            // 4. Quick Stats (The "Your Challenges" Square Cards)
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
                  color: const Color(0xFFFBE4E4), // Light Red/Pink
                  iconColor: _accentColor,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  icon: Icons.check_circle_outline,
                  value: "85%",
                  label: "Quality A",
                  color: const Color(0xFFE8F1ED), // Light Green
                  iconColor: _bgGreen,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  icon: Icons.scale,
                  value: "45kg",
                  label: "Total Wt.",
                  color: const Color(0xFFFFF4DE), // Light Orange/Yellow
                  iconColor: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),

      // 5. Bottom Navigation Bar
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: _bgGreen.withOpacity(0.2),
          labelTextStyle: MaterialStateProperty.all(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textColor),
          ),
        ),
        child: NavigationBar(
          height: 70,
          backgroundColor: Colors.white,
          elevation: 2,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Stats'),
            NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  // Helper for the "Green Pill" rows
  Widget _buildBatchTile({
    required String time,
    required String title,
    required String status,
    required bool isCompleted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _bgGreen, // The dark sage green from the "Today's Tasks" pills
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
          // Time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              time,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          // Text Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  status,
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                ),
              ],
            ),
          ),
          // Checkbox/Icon
          Icon(
            isCompleted ? Icons.check_circle : Icons.sync,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }

  // Helper for the "Square Stats" cards
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
