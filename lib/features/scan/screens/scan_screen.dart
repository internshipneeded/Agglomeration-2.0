import 'dart:io';
import 'package:camera/camera.dart'; // 1. Import Camera
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'batch_preview_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  // Camera Controllers
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // Gallery Picker
  final ImagePicker _picker = ImagePicker();

  // Flash State
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  // 1. Initialize Camera
  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Select the first rear-facing camera
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false, // We don't need audio for bottle scanning
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  // 2. Dispose Camera to prevent memory leaks
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // Handle App Lifecycle (e.g., if user minimizes app)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // 3. Capture Image (Using CameraController)
  Future<void> _captureImage() async {
    if (!_isCameraInitialized || _controller == null) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      final XFile image = await _controller!.takePicture();
      // Navigate to preview with the captured image
      _navigateToPreview([File(image.path)]);
    } catch (e) {
      debugPrint("Error capturing image: $e");
    }
  }

  // 4. Select from Gallery (Kept the same)
  Future<void> _pickGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        List<File> fileList = images.map((x) => File(x.path)).toList();
        _navigateToPreview(fileList);
      }
    } catch (e) {
      debugPrint("Gallery Error: $e");
    }
  }

  void _navigateToPreview(List<File> images) {
    // If your BatchPreviewScreen expects to "ADD" to a list,
    // you might want to adjust logic here, but for now this works:
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BatchPreviewScreen(initialImages: images),
      ),
    );
  }

  // Toggle Flash
  void _toggleFlash() {
    if (_controller == null) return;
    setState(() {
      _flashMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    });
    _controller!.setFlashMode(_flashMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // A. Live Camera Preview
          if (_isCameraInitialized && _controller != null)
            SizedBox.expand(
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // B. Top Bar (Close Button)
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // C. Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              padding: const EdgeInsets.only(bottom: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 1. Gallery Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _pickGallery,
                          icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 32),
                        ),
                        const Text("Import", style: TextStyle(color: Colors.white, fontSize: 12))
                      ],
                    ),

                    // 2. Shutter Button (The Big White Circle)
                    GestureDetector(
                      onTap: _captureImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 5),
                          color: Colors.white24, // Semi-transparent fill
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // 3. Flash Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _toggleFlash,
                          icon: Icon(
                              _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                              color: _flashMode == FlashMode.off ? Colors.white : Colors.yellow,
                              size: 32
                          ),
                        ),
                        Text(
                            _flashMode == FlashMode.off ? "Flash Off" : "Flash On",
                            style: const TextStyle(color: Colors.white, fontSize: 12)
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
