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
      id: json['_id']?.toString() ?? '',
      imageUrl: json['imageUrl'] ?? '',
      // Handle MongoDB date strings safely
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      batchId: json['batchId'] ?? 'Unknown Batch',
      totalBottles: (json['totalBottles'] as num?)?.toInt() ?? 0,
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0.0,
      detections: (json['detections'] as List<dynamic>?)
          ?.map((x) => Detection.fromJson(x as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  // Helper: Converts this single scan to the list format ResultScreen expects
  List<Map<String, dynamic>> toResultList() {
    return [{
      '_id': id,
      'imageUrl': imageUrl,
      'totalBottles': totalBottles,
      'totalValue': totalValue,
      'detections': detections.map((d) => d.toJson()).toList(),
    }];
  }
}
