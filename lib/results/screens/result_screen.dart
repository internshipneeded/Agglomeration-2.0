import 'package:flutter/material.dart';

class ResultScreen extends StatefulWidget {
  final List<Map<String, dynamic>> results;

  const ResultScreen({super.key, required this.results});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _showOverlay = true;

  // Theme Colors
  final Color _bgGreen = const Color(0xFF537A68);
  final Color _accentColor = const Color(0xFFD67D76);
  final Color _textColor = const Color(0xFF2C3E36);
  final Color _cardBg = Colors.white;

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Analysis Results")),
        body: const Center(child: Text("No results to display.")),
      );
    }

    final currentDetections = widget.results[_currentIndex]['detections'] as List? ?? [];
    bool hasMasks = currentDetections.any((d) => d['source'] == 'SAM3' && d['maskUrl'] != null);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              "Batch Result",
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              "${_currentIndex + 1} of ${widget.results.length} Scans",
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (hasMasks)
            IconButton(
              icon: Icon(
                _showOverlay ? Icons.visibility : Icons.visibility_off,
                color: _bgGreen,
              ),
              onPressed: () => setState(() => _showOverlay = !_showOverlay),
              tooltip: "Toggle Segmentation Masks",
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.results.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return _buildResultPage(widget.results[index]);
        },
      ),
    );
  }

  Widget _buildResultPage(Map<String, dynamic> data) {
    final List detections = data['detections'] ?? [];
    final String imageUrl = data['imageUrl'] ?? "";
    final double totalValue = (data['totalValue'] as num?)?.toDouble() ?? 0.0;

    // --- 1. FILTER DATA BY SOURCE ---
    final List sam3Detections = detections.where((d) => d['source'] == 'SAM3').toList();
    final List aggloDetections = detections.where((d) => d['source'] == 'Agglo_2.0').toList();
    final List petDetections = detections.where((d) => d['source'] == 'PetClassifier' || d['source'] == 'SudoKuder').toList();
    final List yoloDetections = detections.where((d) => d['source'] == 'HW_Yolo').toList();
    final List sizeDetections = detections.where((d) => d['source'] == 'ImmortalTree_Size').toList();

    // --- 2. CALCULATE COUNT ---
    int displayCount = sam3Detections.isNotEmpty
        ? sam3Detections.length
        : (data['totalBottles'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. IMAGE CARD
          Center(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(height: 300, color: Colors.grey[100], child: Center(child: CircularProgressIndicator(color: _bgGreen)));
                      },
                      errorBuilder: (c, e, s) => Container(height: 300, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                    if (_showOverlay)
                      for (var det in sam3Detections)
                        if (det['maskUrl'] != null && det['maskUrl'].toString().isNotEmpty)
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.5,
                              child: Image.network(
                                det['maskUrl'],
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const SizedBox(),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // B. STATS ROW
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem("Total Value", "₹${totalValue.toStringAsFixed(1)}", _bgGreen),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                _buildStatItem("Count", "$displayCount Items", _textColor),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                _buildStatItem("AI Status", "Active", _accentColor),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // C. MATERIAL ANALYSIS
          if (petDetections.isNotEmpty) ...[
            Text("Material Analysis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 16),
            ...petDetections.map((det) => _buildMaterialTile(det)).toList(),
            const SizedBox(height: 30),
          ] else if (displayCount > 0) ...[
            Text("Material Analysis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 16),
            _buildUnknownMaterialTile(),
            const SizedBox(height: 30),
          ],

          // D. IDENTIFIED BRANDS
          if (aggloDetections.isNotEmpty) ...[
            Text("Identified Brands", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 16),
            ...aggloDetections.map((det) => _buildBrandTile(det)).toList(),
            const SizedBox(height: 30),
          ],

          // E. HARDWARE VERIFICATION (HW YOLO)
          if (yoloDetections.isNotEmpty) ...[
            Text("Hardware Verification", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 16),
            ...yoloDetections.map((det) => _buildYoloTile(det)).toList(),
            const SizedBox(height: 30),
          ] else if (displayCount > 0) ...[
            // ⬇️ NEW: Fallback for YOLO
            Text("Hardware Verification", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 16),
            _buildUnknownYoloTile(),
            const SizedBox(height: 30),
          ],

          // F. SIZE ESTIMATION
          if (sizeDetections.isNotEmpty) ...[
            Text("Size Analysis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 16),
            ...sizeDetections.map((det) => _buildSizeTile(det)).toList(),
            const SizedBox(height: 30),
          ],

          // G. SEGMENTATION DETAILS
          if (sam3Detections.isNotEmpty) ...[
            Text("Segmentation Masks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 16),
            ...sam3Detections.map((det) => _buildSegmentationTile(det)).toList(),
          ],

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: valueColor, fontFamily: 'Poppins')),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMaterialTile(Map<String, dynamic> det) {
    String material = det['material'] ?? "Unknown";
    bool isPet = material.toUpperCase() == 'PET';
    bool isClear = (det['color'] ?? 'Clear') == 'Clear';
    double confidence = ((det['confidence'] as num?)?.toDouble() ?? 0.0) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPet ? _bgGreen.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPet ? _bgGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isPet ? Icons.recycling : Icons.do_not_disturb_alt, color: isPet ? _bgGreen : Colors.red, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isPet ? "PET Plastic" : "Non-PET Contaminant", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildTag(isClear ? "Clear" : "Colored"),
                    const SizedBox(width: 8),
                    _buildTag(isPet ? "Recyclable" : "Reject", isError: !isPet),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text("${confidence.toInt()}%", style: TextStyle(fontWeight: FontWeight.bold, color: isPet ? _bgGreen : Colors.red)),
              Text("Conf.", style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownMaterialTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.help_outline, color: Colors.grey, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Material Unknown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                const SizedBox(height: 4),
                Text("Detector could not confirm material type.", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandTile(Map<String, dynamic> det) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: _bgGreen.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bgGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified, color: _bgGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(det['brand'] ?? "Unknown Brand", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                const SizedBox(height: 4),
                Text("Verified by Agglo 2.0", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYoloTile(Map<String, dynamic> det) {
    final meta = det['meta'] as Map<String, dynamic>? ?? {};
    final double height = (meta['height_cm'] as num?)?.toDouble() ?? 0.0;
    final double diameter = (meta['diameter_cm'] as num?)?.toDouble() ?? 0.0;
    final double confidence = ((det['confidence'] as num?)?.toDouble() ?? 0.0) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.straighten, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Dimensions Detected", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                const SizedBox(height: 4),
                if (height > 0 || diameter > 0)
                  Text("H: ${height.toStringAsFixed(1)} cm  |  Ø: ${diameter.toStringAsFixed(1)} cm", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700]))
                else
                  Text("Measurement data unavailable", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Column(
            children: [
              Text("${confidence.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              Text("Score", style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }

  // ⬇️ NEW: YOLO FALLBACK TILE
  Widget _buildUnknownYoloTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.grey, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Verification Failed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                const SizedBox(height: 4),
                Text("HW Yolo could not verify object dimensions.", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeTile(Map<String, dynamic> det) {
    final meta = det['meta'] as Map<String, dynamic>? ?? {};
    String rawLabel = meta['detected_size'] ?? "Unknown";
    final double confidence = ((det['confidence'] as num?)?.toDouble() ?? 0.0) * 100;

    // 1. Parsing Logic
    String displayLabel = rawLabel;
    String category = "Custom Size";
    double? mlValue;

    String cleanLabel = rawLabel.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final numRegex = RegExp(r'(\d+(\.\d+)?)');
    final match = numRegex.firstMatch(cleanLabel);

    if (match != null) {
      double val = double.parse(match.group(1)!);

      if (cleanLabel.contains('cl')) {
        mlValue = val * 10;
        displayLabel = "${mlValue.toInt()}ml";
      } else if (cleanLabel.contains('ml')) {
        mlValue = val;
        displayLabel = "${mlValue.toInt()}ml";
      } else if (cleanLabel.contains('l')) {
        mlValue = val * 1000;
        displayLabel = "${mlValue.toInt()}ml / $val L";
      }
    }

    // 2. Categorization Logic
    if (mlValue != null) {
      if (mlValue >= 150 && mlValue <= 350) {
        category = "Small Single-Serve";
      } else if (mlValue >= 450 && mlValue <= 750) {
        category = "Standard Single-Serve";
      } else if (mlValue >= 900 && mlValue <= 1100) {
        category = "Large Single-Serve";
      } else if (mlValue >= 1400 && mlValue <= 2100) {
        category = "Family Pack";
      } else if (mlValue > 2100) {
        category = "Bulk";
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_size_select_small, color: Colors.purple, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Bottle Size", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    children: [
                      TextSpan(text: displayLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (category != "Custom Size")
                        TextSpan(text: "  ($category)", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text("${confidence.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
              Text("Conf.", style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentationTile(Map<String, dynamic> det) {
    final double confidence = ((det['confidence'] as num?)?.toDouble() ?? 0.0) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 55,
              height: 55,
              color: Colors.grey[100],
              child: det['maskUrl'] != null
                  ? Image.network(
                det['maskUrl'],
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
              )
                  : const Icon(Icons.image_aspect_ratio, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(det['label']?.toString().toUpperCase() ?? "OBJECT", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text("Confidence: ${confidence.toStringAsFixed(0)}%", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text("SAM3", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, {bool isError = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isError ? Colors.red.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isError ? Colors.red : Colors.grey[700]),
      ),
    );
  }
}
