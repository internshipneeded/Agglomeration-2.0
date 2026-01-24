import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  // Update this with your actual Render URL
  static const String baseUrl = 'https://pet-perplexity.onrender.com/api';

  final _storage = const FlutterSecureStorage();

  // 1. Login
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        await _storage.write(key: 'jwt_token', value: data['token']);
        return true;
      }
      return false;
    } catch (e) {
      print('Login Error: $e');
      return false;
    }
  }

  // 2. Register
  Future<bool> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        await _storage.write(key: 'jwt_token', value: data['token']);
        return true;
      }
      return false;
    } catch (e) {
      print('Register Error: $e');
      return false;
    }
  }

  // 3. Get User Profile (Used by Profile Screen)
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/user/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Error fetching profile: $e");
      return null;
    }
  }

  // 4. Update Profile
  Future<bool> updateProfile(String name, String? filePath) async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      var uri = Uri.parse('$baseUrl/user/update');

      var request = http.MultipartRequest('PUT', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['name'] = name;

      if (filePath != null) {
        var pic = await http.MultipartFile.fromPath('profilePic', filePath);
        request.files.add(pic);
      }

      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print('Update Error: $e');
      return false;
    }
  }

  // 5. Logout
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }
}
