import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../history/models/scan.dart';
import '../../history/models/detection.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // --- Theme Colors ---
  final Color _bgGreen = const Color(0xFF537A68);
  final Color _accentColor = const Color(0xFFD67D76);
  final Color _textColor = const Color(0xFF2C3E36);
  final Color _cardBg = const Color(0xFFF7F9F8);

  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;

  // --- Data Variables ---
  int _totalBottles = 0;
  double _totalWeightKg = 0.0;
  double _estimatedRevenue = 0.0;
  double _qualityGrade = 0.0;

  int _petCount = 0;
  int _nonPetCount = 0;
  Map<String, int> _sizeDistribution = {
    'Small': 0, 'Standard': 0, 'Large': 0, 'Family': 0, 'Bulk': 0
  };

  // --- UI State ---
  int _pieTouchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchAndCalculateStats();
  }

  // --- FETCH & CALCULATE (Same as before) ---
  Future<void> _fetchAndCalculateStats() async {
    const String baseUrl = 'https://pet-perplexity.onrender.com/api/scan/history';

    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Scan> scans = data.map((json) => Scan.fromJson(json)).toList();
        _processData(scans);
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData(List<Scan> scans) {
    int totalClearPet = 0;
    _totalBottles = 0;
    _totalWeightKg = 0;
    _estimatedRevenue = 0;
    _petCount = 0;
    _nonPetCount = 0;
    _sizeDistribution = {'Small': 0, 'Standard': 0, 'Large': 0, 'Family': 0, 'Bulk': 0};

    for (var scan in scans) {
      _totalBottles += scan.totalBottles;
      _estimatedRevenue += scan.totalValue;

      var materialDet = scan.detections.firstWhere(
              (d) => d.source == 'PetClassifier',
          orElse: () => Detection(source: 'Unknown', label: '', confidence: 0, brand: '', color: 'Unknown', material: 'Unknown')
      );

      if (materialDet.source == 'Unknown') {
        materialDet = scan.detections.firstWhere(
                (d) => d.source == 'Agglo_2.0',
            orElse: () => materialDet
        );
      }

      if (materialDet.material.toUpperCase() == 'PET') {
        _petCount++;
        if (materialDet.color.toLowerCase().contains('clear') ||
            materialDet.color.toLowerCase().contains('transparent')) {
          totalClearPet++;
        }
      } else if (materialDet.material != 'Unknown') {
        _nonPetCount++;
      }

      var sizeDet = scan.detections.firstWhere(
              (d) => d.source == 'ImmortalTree_Size',
          orElse: () => Detection(source: 'Unknown', label: '', confidence: 0, brand: '', color: '', material: '')
      );

      if (sizeDet.source != 'Unknown') {
        String sizeCategory = _parseSize(sizeDet.meta?['detected_size']);
        _sizeDistribution[sizeCategory] = (_sizeDistribution[sizeCategory] ?? 0) + 1;

        double weightGrams = 0;
        switch (sizeCategory) {
          case 'Small': weightGrams = 12; break;
          case 'Standard': weightGrams = 22; break;
          case 'Large': weightGrams = 40; break;
          case 'Family': weightGrams = 60; break;
          case 'Bulk': weightGrams = 70; break;
          default: weightGrams = 20;
        }
        _totalWeightKg += (weightGrams / 1000);
      } else {
        _totalWeightKg += 0.02;
      }
    }
    _qualityGrade = _totalBottles > 0 ? (totalClearPet / _totalBottles) : 0.0;
  }

  String _parseSize(String? rawLabel) {
    if (rawLabel == null) return "Standard";
    String clean = rawLabel.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final numRegex = RegExp(r'(\d+(\.\d+)?)');
    final match = numRegex.firstMatch(clean);

    if (match != null) {
      double val = double.parse(match.group(1)!);
      double ml = val;
      if (clean.contains('ml')) {
        ml = val;
      } else if (clean.contains('cl')) {
        ml = val * 10;
      } else if (clean.contains('l')) {
        ml = val * 1000;
      }

      if (ml <= 350) return 'Small';
      if (ml <= 750) return 'Standard';
      if (ml <= 1100) return 'Large';
      if (ml <= 2100) return 'Family';
      return 'Bulk';
    }
    return "Standard";
  }

  // --- PDF GENERATION LOGIC ---
  Future<void> _generateAndExportPdf() async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Pet Perplexity Report", style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.green800)),
                    pw.Text("Agglomeration 2.0", style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              pw.Text("Batch Summary", style: pw.TextStyle(font: fontBold, fontSize: 18)),
              pw.SizedBox(height: 10),

              // Summary Grid
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildPdfStatCard("Total Items", "$_totalBottles", font, fontBold),
                  _buildPdfStatCard("Est. Weight", "${_totalWeightKg.toStringAsFixed(2)} kg", font, fontBold),
                  _buildPdfStatCard("Est. Revenue", "Rs. ${_estimatedRevenue.toStringAsFixed(0)}", font, fontBold),
                  _buildPdfStatCard("Clear PET", "${(_qualityGrade * 100).toStringAsFixed(1)}%", font, fontBold),
                ],
              ),
              pw.SizedBox(height: 30),

              // Material Table
              pw.Text("Material Composition", style: pw.TextStyle(font: fontBold, fontSize: 16)),
              pw.SizedBox(height: 5),
              pw.Table.fromTextArray(
                headers: ['Material Type', 'Count', 'Percentage'],
                data: [
                  ['PET Plastic', '$_petCount', _totalBottles > 0 ? '${((_petCount/_totalBottles)*100).toStringAsFixed(1)}%' : '0%'],
                  ['Non-PET (Contaminant)', '$_nonPetCount', _totalBottles > 0 ? '${((_nonPetCount/_totalBottles)*100).toStringAsFixed(1)}%' : '0%'],
                ],
                headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
                cellStyle: pw.TextStyle(font: font),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 30),

              // Size Table
              pw.Text("Size Distribution Breakdown", style: pw.TextStyle(font: fontBold, fontSize: 16)),
              pw.SizedBox(height: 5),
              pw.Table.fromTextArray(
                headers: ['Size Category', 'Count'],
                data: _sizeDistribution.entries.map((e) => [e.key, '${e.value}']).toList(),
                headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange700),
                cellStyle: pw.TextStyle(font: font),
                cellAlignment: pw.Alignment.centerLeft,
              ),

              pw.SizedBox(height: 40),
              pw.Divider(),
              pw.Text("Generated on ${DateTime.now().toString().split('.')[0]}", style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    // Trigger Download/Share
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'pet_perplexity_report.pdf');
  }

  pw.Widget _buildPdfStatCard(String label, String value, pw.Font font, pw.Font bold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 16, color: PdfColors.green900)),
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Analytics", style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: _bgGreen),
            onPressed: () {
              _generateAndExportPdf();
            },
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _bgGreen))
          : RefreshIndicator(
        onRefresh: () async {
          setState(() => _isLoading = true);
          await _fetchAndCalculateStats();
        },
        color: _bgGreen,
        child: _totalBottles == 0
            ? _buildEmptyState()
            : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderDate(),
              const SizedBox(height: 20),
              _buildSummaryGrid(),
              const SizedBox(height: 30),
              _buildSectionHeader("Material Purity", Icons.pie_chart),
              const SizedBox(height: 16),
              _buildInteractivePieChart(),
              const SizedBox(height: 30),
              _buildSectionHeader("Size Distribution", Icons.bar_chart),
              const SizedBox(height: 16),
              _buildInteractiveBarChart(),
              const SizedBox(height: 30),
              _buildQualityCard(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Keep ALL your existing widget builders: _buildSummaryGrid, _buildInteractivePieChart, etc.) ...
  // Paste them here unchanged from the previous code block.

  Widget _buildHeaderDate() {
    return Text(
      "Last Updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      style: TextStyle(color: Colors.grey[500], fontSize: 12),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _bgGreen),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Text("No Data", style: TextStyle(color: Colors.grey[600])));
  }

  Widget _buildSummaryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _buildStatCard("Total Bottles", _totalBottles, Icons.recycling, Colors.blue),
        _buildStatCard("Est. Weight", _totalWeightKg, Icons.scale, Colors.orange, unit: "kg", isDouble: true),
        _buildStatCard("Revenue", _estimatedRevenue, Icons.currency_rupee, _bgGreen, isCurrency: true),
        _buildStatCard("Quality", _qualityGrade * 100, Icons.verified, _accentColor, unit: "%", isDouble: true),
      ],
    );
  }

  Widget _buildStatCard(String label, num value, IconData icon, Color color, {String unit = "", bool isCurrency = false, bool isDouble = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCurrency ? "₹${value.toStringAsFixed(0)}" : "${isDouble ? value.toStringAsFixed(1) : value.toInt()}$unit",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textColor),
              ),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractivePieChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            sectionsSpace: 4,
            centerSpaceRadius: 40,
            sections: [
              PieChartSectionData(color: _bgGreen, value: _petCount.toDouble(), title: _petCount > 0 ? '${((_petCount / (_petCount + _nonPetCount)) * 100).toInt()}%' : '', radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              PieChartSectionData(color: _accentColor, value: _nonPetCount.toDouble(), title: _nonPetCount > 0 ? '${((_nonPetCount / (_petCount + _nonPetCount)) * 100).toInt()}%' : '', radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveBarChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20)),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (_sizeDistribution.values.isEmpty ? 0 : _sizeDistribution.values.reduce((a, b) => a > b ? a : b)) + 2.0,
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(fontSize: 10, fontWeight: FontWeight.bold);
                  switch (value.toInt()) {
                    case 0: return const Text('Small', style: style);
                    case 1: return const Text('Std', style: style);
                    case 2: return const Text('Large', style: style);
                    case 3: return const Text('Fam', style: style);
                    case 4: return const Text('Bulk', style: style);
                    default: return const Text('');
                  }
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            _makeGroupData(0, _sizeDistribution['Small']!.toDouble()),
            _makeGroupData(1, _sizeDistribution['Standard']!.toDouble()),
            _makeGroupData(2, _sizeDistribution['Large']!.toDouble()),
            _makeGroupData(3, _sizeDistribution['Family']!.toDouble()),
            _makeGroupData(4, _sizeDistribution['Bulk']!.toDouble()),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y) {
    return BarChartGroupData(x: x, barRods: [BarChartRodData(toY: y, color: _bgGreen, width: 20, borderRadius: BorderRadius.circular(4))]);
  }

  Widget _buildQualityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_textColor, const Color(0xFF1A2822)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Batch Quality Grade", style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text((_qualityGrade * 100) > 80 ? "Gold Standard" : "Standard Grade", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
