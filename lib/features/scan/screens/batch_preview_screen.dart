import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../results/screens/result_screen.dart';
import '../../../services/scan_service.dart'; // Import updated service

class BatchPreviewScreen extends StatefulWidget {
  final List<File> initialImages;

  const BatchPreviewScreen({super.key, required this.initialImages});

  @override
  State<BatchPreviewScreen> createState() => _BatchPreviewScreenState();
}

class _BatchPreviewScreenState extends State<BatchPreviewScreen> {
  late List<File> _images;
  final ImagePicker _picker = ImagePicker();

  // Initialize Service
  final ScanService _scanService = ScanService();

  bool _isUploading = false;
  final Color _sageGreen = const Color(0xFF5E8C61);

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages);
  }

  // Add more images (Kept same as before)
  Future<void> _addMoreImages() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Add from Camera'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                if (photo != null) setState(() => _images.add(File(photo.path)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Add from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final List<XFile> photos = await _picker.pickMultiImage();
                if (photos.isNotEmpty) {
                  setState(() => _images.addAll(photos.map((e) => File(e.path))));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Updated: Send images to Node.js Backend
  void _processBatch() async {
    if (_images.isEmpty) return;

    setState(() => _isUploading = true);

    // Call the Service
    List<Map<String, dynamic>> results = await _scanService.uploadBatchToBackend(_images);

    if (mounted) {
      setState(() => _isUploading = false);

      if (results.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(results: results),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Some uploads failed. Check console."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text("Review Scan (${_images.length})", style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined, color: Colors.white),
            onPressed: _addMoreImages,
            tooltip: "Add Page",
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Image Carousel
          Expanded(
            child: _images.isEmpty
                ? const Center(child: Text("No images selected", style: TextStyle(color: Colors.white54)))
                : PageView.builder(
              itemCount: _images.length,
              controller: PageController(viewportFraction: 0.85),
              itemBuilder: (context, index) {
                return _buildImageCard(index);
              },
            ),
          ),

          // 2. Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isUploading || _images.isEmpty ? null : _processBatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sageGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isUploading
                      ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                      : const Text(
                    "Save & Analyze Batch",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(int index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: FileImage(_images[index]),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 15,
                  right: 15,
                  child: GestureDetector(
                    onTap: () => setState(() => _images.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Text("Page ${index + 1} of ${_images.length}",
            style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 10),
      ],
    );
  }
}
