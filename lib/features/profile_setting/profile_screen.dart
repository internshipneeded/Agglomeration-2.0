import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/auth_service.dart'; // Ensure this path is correct
import '../onboarding/auth/screens/login_screen.dart';

// Define Colors locally or import from your app_colors.dart if you have it
class AppColors {
  static const Color primaryGreen = Color(0xFF5E8C61); // Sage Green
  static const Color accentBrown = Color(0xFFD67D76);  // Terra Cotta
  static const Color lightBg = Color(0xFFF4F7F5);      // Light Background
  static const Color darkText = Color(0xFF2C3E2D);     // Dark Green Text
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  File? _selectedImage; // Image selected from gallery
  String? _serverImageUrl; // Image URL from database (Cloudinary)
  bool _isLoading = true; // Start true to show spinner while fetching data
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // 1. Fetch User Data on Init
  Future<void> _fetchUserData() async {
    final userData = await _authService.getUserProfile();

    if (mounted) {
      if (userData != null) {
        setState(() {
          _nameController.text = userData['name'] ?? "";
          _emailController.text = userData['email'] ?? "";
          _serverImageUrl = userData['profilePic'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showSnackBar("Failed to load profile", isError: true);
      }
    }
  }

  // 2. Pick Image Logic
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // 3. Save Changes
  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    bool success = await _authService.updateProfile(
        _nameController.text.trim(),
        _selectedImage?.path
    );

    setState(() => _isSaving = false);

    if (success) {
      _showSnackBar("Profile updated successfully!");
    } else {
      _showSnackBar("Failed to update profile", isError: true);
    }
  }

  // 4. Logout Logic
  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  // Helper for SnackBars
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- PROFILE PICTURE ---
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryGreen, width: 4),
                      color: AppColors.lightBg,
                      image: _getProfileImage(),
                    ),
                    child: (_selectedImage == null && (_serverImageUrl == null || _serverImageUrl!.isEmpty))
                        ? const Icon(Icons.person, size: 80, color: Colors.grey)
                        : null,
                  ),

                  // Camera Icon
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accentBrown,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- TEXT FIELDS ---
            _buildTextField(
              controller: _nameController,
              label: "Full Name",
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 20),

            _buildTextField(
              controller: _emailController,
              label: "Email Address",
              icon: Icons.email_outlined,
              isReadOnly: true, // Email cannot be changed
            ),
            const SizedBox(height: 40),

            // --- SAVE BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Save Changes",
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- LOGOUT BUTTON ---
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text(
                "Log Out",
                style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Logic to choose which image to show
  DecorationImage? _getProfileImage() {
    if (_selectedImage != null) {
      // 1. User picked a new photo
      return DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover);
    }
    if (_serverImageUrl != null && _serverImageUrl!.isNotEmpty) {
      // 2. User has a photo from backend
      return DecorationImage(image: NetworkImage(_serverImageUrl!), fit: BoxFit.cover);
    }
    // 3. No photo
    return null;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isReadOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: isReadOnly,
      style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: AppColors.primaryGreen),
        filled: true,
        fillColor: isReadOnly ? Colors.grey[100] : AppColors.lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
    );
  }
}