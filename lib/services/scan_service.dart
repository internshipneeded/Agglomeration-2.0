import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart'; // Optional: Add 'uuid' to pubspec.yaml if you want unique batch IDs

class ScanService {
  // Your Backend URL
  static const String baseUrl = 'https://pet-perplexity.onrender.com/api';

  final _storage = const FlutterSecureStorage();
  final _uuid = const Uuid(); // Optional

  Future<List<Map<String, dynamic>>> uploadBatchToBackend(List<File> images) async {
    final uri = Uri.parse('$baseUrl/scan');
    String? token = await _storage.read(key: 'jwt_token');

    if (token == null) {
      print("Error: No JWT Token found.");
      return [];
    }

    List<Map<String, dynamic>> scanResults = [];
    String currentBatchId = _uuid.v4(); // Generate a unique ID for this batch

    for (var image in images) {
      try {
        var request = http.MultipartRequest('POST', uri);

        request.headers['Authorization'] = 'Bearer $token';

        // 1. Add the Image (Matches upload.single('image'))
        var pic = await http.MultipartFile.fromPath('image', image.path);
        request.files.add(pic);

        // 2. Add Batch ID (Matches req.body.batchId)
        request.fields['batchId'] = currentBatchId;

        print("Uploading ${image.path.split('/').last}...");

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          scanResults.add(data);
          print("✅ Success! ID: ${data['_id']}");
        } else {
          print("❌ Upload Failed [${response.statusCode}]: ${response.body}");
        }
      } catch (e) {
        print("❌ Service Error: $e");
      }
    }

    return scanResults;
  }
}
