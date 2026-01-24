class Detection {
  final String source; // e.g., "SAM3", "PetClassifier", "HW_Yolo"
  final String label;
  final double confidence;
  final String brand;
  final String color;
  final String material;
  final String? maskUrl; // For SAM3
  final Map<String, dynamic>? meta; // For height, diameter, probs

  Detection({
    required this.source,
    required this.label,
    required this.confidence,
    required this.brand,
    required this.color,
    required this.material,
    this.maskUrl,
    this.meta,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      source: json['source'] ?? 'Unknown',
      label: json['label'] ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      brand: json['brand'] ?? 'Unknown',
      color: json['color'] ?? 'Unknown',
      material: json['material'] ?? 'Unknown',
      maskUrl: json['maskUrl'],
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }

  // Converts back to Map for passing to ResultScreen
  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'label': label,
      'confidence': confidence,
      'brand': brand,
      'color': color,
      'material': material,
      'maskUrl': maskUrl,
      'meta': meta,
    };
  }
}
