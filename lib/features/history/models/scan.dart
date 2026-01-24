import 'detection.dart';

class Scan {
  final String id;
  final String imageUrl;
  final DateTime timestamp;
  final String batchId;
  final int totalBottles;
  final double totalValue;
  final List<Detection> detections;

  Scan({
    required this.id,
    required this.imageUrl,
    required this.timestamp,
    required this.batchId,
    required this.totalBottles,
    required this.totalValue,
    required this.detections,
  });

  factory Scan.fromJson(Map<String, dynamic> json) {
    return Scan(
      id: json['_id'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      batchId: json['batchId'] ?? 'Unknown Batch',
      totalBottles: json['totalBottles'] ?? 0,
      totalValue: (json['totalValue'] ?? 0).toDouble(),
      detections:
          (json['detections'] as List<dynamic>?)
              ?.map((x) => Detection.fromJson(x))
              .toList() ??
          [],
    );
  }
}
