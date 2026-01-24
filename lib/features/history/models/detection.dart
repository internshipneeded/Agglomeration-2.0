class Detection {
  final String label;
  final double confidence;
  final String brand;
  final String color;
  final String material;

  Detection({
    required this.label,
    required this.confidence,
    required this.brand,
    required this.color,
    required this.material,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      label: json['label'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
      brand: json['brand'] ?? 'Unknown',
      color: json['color'] ?? 'Unknown',
      material: json['material'] ?? 'Unknown',
    );
  }
}
