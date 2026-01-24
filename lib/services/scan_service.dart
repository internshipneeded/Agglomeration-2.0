import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ScanService {
  // 1. Replace with YOUR Cloud Name
  final String cloudName = "petperplexity";

  // 2. Replace with YOUR Unsigned Upload Preset Name
  final String uploadPreset = "scan_image_upload";

  /// Uploads a list of images directly to Cloudinary and returns the URLs
  Future<List<String>> uploadToCloudinary(List<File> images) async {
    List<String> uploadedUrls = [];
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    try {
      for (var image in images) {
        // Create Multipart Request
        final request = http.MultipartRequest('POST', url);

        // Add the Upload Preset (Required for direct upload)
        request.fields['upload_preset'] = uploadPreset;

        // Add the File
        final file = await http.MultipartFile.fromPath('file', image.path);
        request.files.add(file);

        // Send Request
        final response = await request.send();
        final responseData = await http.Response.fromStream(response);

        if (response.statusCode == 200) {
          final data = jsonDecode(responseData.body);
          final String secureUrl = data['secure_url'];
          print("Uploaded: $secureUrl");
          uploadedUrls.add(secureUrl);
        } else {
          print("Cloudinary Error: ${responseData.body}");
        }
      }

      return uploadedUrls;

    } catch (e) {
      print("Upload Error: $e");
      return [];
    }
  }

  /// Placeholder: Send these URLs to your Node.js backend later
  Future<void> sendUrlsToBackend(List<String> urls) async {
    // We will implement this part when you build the backend logic
    // to create the Scan model and trigger the ML classification.
    print("Ready to send to backend: $urls");
  }
}
