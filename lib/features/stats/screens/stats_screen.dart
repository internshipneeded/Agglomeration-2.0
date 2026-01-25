import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../history/models/detection.dart';
import '../../history/models/scan.dart';

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

  // --- Master Data ---
  List<Scan> _allScans = [];
  Scan? _selectedBatch; // Null implies "All Time"

  // --- Calculated Stats (Dynamic) ---
  int _totalItems = 0;
  double _purityPercentage = 0.0; // % Clear PET
  double _contaminationRate = 0.0; // % Non-PET
  String _dominantSize = "N/A"; // Most common size

  int _petCount = 0;
  int _nonPetCount = 0;
  Map<String, int> _sizeDistribution = {
    'Small': 0,
    'Standard': 0,
    'Large': 0,
    'Family': 0,
    'Bulk': 0,
  };

  // --- UI State ---
  int _pieTouchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchAllScans();
  }

  // --- 1. FETCH ALL DATA ---
  Future<void> _fetchAllScans() async {
    const String baseUrl =
        'https://pet-perplexity.onrender.com/api/scan/history';

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
        setState(() {
          _allScans = data.map((json) => Scan.fromJson(json)).toList();
          // Sort by date descending
          _allScans.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _isLoading = false;
        });

        // Initial Calculation (All Time)
        _calculateStats();
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. CALCULATE STATS (Dynamic Scope) ---
  void _calculateStats() {
    // Determine Scope: Single Batch or All Scans
    final List<Scan> targetScans = _selectedBatch != null
        ? [_selectedBatch!]
        : _allScans;

    // Reset Counters
    _totalItems = 0;
    _petCount = 0;
    _nonPetCount = 0;
    _sizeDistribution = {
      'Small': 0,
      'Standard': 0,
      'Large': 0,
      'Family': 0,
      'Bulk': 0,
    };
    int totalClearPet = 0;

    for (var scan in targetScans) {
      // 1. Count Total
      _totalItems += scan.totalBottles;

      // 2. Material Logic
      var materialDet = scan.detections.firstWhere(
        (d) => d.source == 'PetClassifier',
        orElse: () => Detection(
          source: 'Unknown',
          label: '',
          confidence: 0,
          brand: '',
          color: 'Unknown',
          material: 'Unknown',
        ),
      );

      if (materialDet.source == 'Unknown') {
        materialDet = scan.detections.firstWhere(
          (d) => d.source == 'Agglo_2.0',
          orElse: () => materialDet,
        );
      }

      if (materialDet.material.toUpperCase() == 'PET') {
        _petCount++;
        // Track Clear PET for Purity
        if (materialDet.color.toLowerCase().contains('clear') ||
            materialDet.color.toLowerCase().contains('transparent')) {
          totalClearPet++;
        }
      } else if (materialDet.material != 'Unknown') {
        _nonPetCount++;
      }

      // 3. Size Logic
      var sizeDet = scan.detections.firstWhere(
        (d) => d.source == 'ImmortalTree_Size',
        orElse: () => Detection(
          source: 'Unknown',
          label: '',
          confidence: 0,
          brand: '',
          color: '',
          material: '',
        ),
      );

      if (sizeDet.source != 'Unknown') {
        String sizeCategory = _parseSize(sizeDet.meta?['detected_size']);
        _sizeDistribution[sizeCategory] =
            (_sizeDistribution[sizeCategory] ?? 0) + 1;
      }
    }

    // Final Percentages
    if (_totalItems > 0) {
      _purityPercentage = (totalClearPet / _totalItems) * 100;
      _contaminationRate = (_nonPetCount / (_petCount + _nonPetCount)) * 100;
    } else {
      _purityPercentage = 0.0;
      _contaminationRate = 0.0;
    }

    // Determine Dominant Size
    var sortedSizes = _sizeDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedSizes.isNotEmpty && sortedSizes.first.value > 0) {
      _dominantSize = sortedSizes.first.key;
    } else {
      _dominantSize = "N/A";
    }
  }

  String _parseSize(String? rawLabel) {
    if (rawLabel == null) return "Standard";
    String clean = rawLabel.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final numRegex = RegExp(r'(\d+(\.\d+)?)');
    final match = numRegex.firstMatch(clean);

    if (match != null) {
      double val = double.parse(match.group(1)!);
      double ml = val;

      if (clean.contains('ml'))
        ml = val;
      else if (clean.contains('cl'))
        ml = val * 10;
      else if (clean.contains('l'))
        ml = val * 1000;

      if (ml <= 350) return 'Small';
      if (ml <= 750) return 'Standard';
      if (ml <= 1100) return 'Large';
      if (ml <= 2100) return 'Family';
      return 'Bulk';
    }
    return "Standard";
  }

  // --- 3. SMART BATCH TITLE HELPER ---
  String _getBatchTitle(Scan? scan) {
    if (scan == null) return "All Time Overview";
    if (scan.batchId == 'Unknown Batch' || scan.batchId.isEmpty) {
      return "Scan ${DateFormat('MM/dd HH:mm').format(scan.timestamp)}";
    }
    String cleanId = scan.batchId.replaceAll('batch_', '');
    if (cleanId.length > 6) {
      return "Batch #${cleanId.substring(cleanId.length - 6)}";
    }
    return "Batch #$cleanId";
  }

  // --- 4. PDF GENERATION (CONTEXT AWARE) ---
  Future<void> _generateAndExportPdf() async {
    final pdf = pw.Document();

    // Fonts
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    // Colors
    final PdfColor primaryColor = PdfColor.fromInt(0xFF537A68);
    final PdfColor lightBg = PdfColor.fromInt(0xFFF7F9F8);
    final PdfColor textColor = PdfColor.fromInt(0xFF2C3E36);

    // Title based on selection
    String reportTitle = _selectedBatch == null
        ? "Cumulative Analytics Report"
        : "${_getBatchTitle(_selectedBatch)} Report";

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        ),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "PET PERPLEXITY",
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 20,
                        color: primaryColor,
                      ),
                    ),
                    pw.Text(
                      "Agglomeration 2.0 System",
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      reportTitle.toUpperCase(),
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                    pw.Text(
                      DateFormat('MMM d, yyyy HH:mm').format(DateTime.now()),
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: primaryColor, thickness: 1.5),
            pw.SizedBox(height: 20),

            // Summary Grid
            pw.Text(
              "KEY METRICS",
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfStatCard(
                  "Total Items",
                  "$_totalItems",
                  PdfColors.blue50,
                  PdfColors.blue700,
                  fontBold,
                  font,
                ),
                _buildPdfStatCard(
                  "Purity (Clear)",
                  "${_purityPercentage.toStringAsFixed(1)}%",
                  PdfColors.green50,
                  PdfColors.green700,
                  fontBold,
                  font,
                ),
                _buildPdfStatCard(
                  "Contamination",
                  "${_contaminationRate.toStringAsFixed(1)}%",
                  PdfColors.orange50,
                  PdfColors.orange700,
                  fontBold,
                  font,
                ),
                _buildPdfStatCard(
                  "Dominant Size",
                  _dominantSize,
                  PdfColors.purple50,
                  PdfColors.purple700,
                  fontBold,
                  font,
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Material Table
            pw.Text(
              "MATERIAL COMPOSITION",
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildVisualTable(
              headers: ['Type', 'Count', 'Distribution'],
              data: [
                [
                  'PET Plastic',
                  '$_petCount',
                  _totalItems > 0 ? (_petCount / _totalItems) : 0.0,
                  PdfColors.green,
                ],
                [
                  'Contaminants',
                  '$_nonPetCount',
                  _totalItems > 0 ? (_nonPetCount / _totalItems) : 0.0,
                  PdfColors.redAccent,
                ],
              ],
              font: font,
              fontBold: fontBold,
            ),

            pw.SizedBox(height: 30),

            // Size Table
            pw.Text(
              "SIZE CLASSIFICATION",
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        "Category",
                        style: pw.TextStyle(font: fontBold, fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        "Count",
                        style: pw.TextStyle(font: fontBold, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                ..._sizeDistribution.entries
                    .map(
                      (e) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              e.key,
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${e.value}',
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ],
            ),

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Center(
              child: pw.Text(
                "Generated by Pet Perplexity",
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'analytics_report.pdf',
    );
  }

  pw.Widget _buildPdfStatCard(
    String label,
    String value,
    PdfColor bg,
    PdfColor accent,
    pw.Font fontBold,
    pw.Font font,
  ) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(font: fontBold, fontSize: 14, color: accent),
          ),
          pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildVisualTable({
    required List<String> headers,
    required List<List<dynamic>> data,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FixedColumnWidth(50),
        2: const pw.FlexColumnWidth(4),
      },
      children: [
        pw.TableRow(
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                  ),
                ),
              )
              .toList(),
        ),
        ...data
            .map(
              (row) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Text(row[0], style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Text(row[1], style: pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: (row[2] * 100).toInt(),
                          child: pw.Container(
                            height: 6,
                            decoration: pw.BoxDecoration(
                              color: row[3],
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: (100 - (row[2] * 100)).toInt(),
                          child: pw.Container(
                            height: 6,
                            color: PdfColors.grey100,
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          "${(row[2] * 100).toStringAsFixed(1)}%",
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ],
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Analytics",
          style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: _bgGreen),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Generating PDF..."),
                  duration: Duration(seconds: 1),
                ),
              );
              try {
                await _generateAndExportPdf();
              } catch (e) {
                debugPrint("PDF Error: $e");
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _bgGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BATCH DROPDOWN ---
                  _buildBatchDropdown(),
                  const SizedBox(height: 20),

                  // --- SUMMARY CARDS ---
                  _buildSummaryGrid(),
                  const SizedBox(height: 30),

                  // --- PIE CHART ---
                  _buildSectionHeader("Material Composition", Icons.pie_chart),
                  const SizedBox(height: 16),
                  _buildInteractivePieChart(),
                  const SizedBox(height: 30),

                  // --- BAR CHART ---
                  _buildSectionHeader("Size Breakdown", Icons.bar_chart),
                  const SizedBox(height: 16),
                  _buildInteractiveBarChart(),
                  const SizedBox(height: 30),

                  // --- QUALITY CARD ---
                  _buildQualityCard(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  // --- NEW: BATCH SELECTOR WIDGET ---
  Widget _buildBatchDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bgGreen.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Scan?>(
          value: _selectedBatch,
          icon: Icon(Icons.keyboard_arrow_down, color: _bgGreen),
          isExpanded: true,
          hint: Text(
            "Select Batch (Showing All)",
            style: TextStyle(color: _textColor),
          ),
          items: [
            // Option for All Time
            DropdownMenuItem<Scan?>(
              value: null,
              child: Text(
                "All Time Overview",
                style: TextStyle(fontWeight: FontWeight.bold, color: _bgGreen),
              ),
            ),
            // Options for individual batches
            ..._allScans.map((scan) {
              return DropdownMenuItem<Scan?>(
                value: scan,
                child: Text(
                  "${_getBatchTitle(scan)} (${DateFormat('MM/dd').format(scan.timestamp)})",
                  style: TextStyle(color: _textColor),
                ),
              );
            }).toList(),
          ],
          onChanged: (Scan? newValue) {
            setState(() {
              _selectedBatch = newValue;
              _calculateStats(); // Recalculate metrics for selected batch
            });
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 20, color: _bgGreen),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: _textColor,
        ),
      ),
    ],
  );

  Widget _buildSummaryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _buildStatCard(
          "Total Items",
          _totalItems,
          Icons.recycling,
          Colors.blue,
        ),
        _buildStatCard(
          "Purity (Clear)",
          _purityPercentage,
          Icons.verified,
          _bgGreen,
          unit: "%",
          isDouble: true,
        ),
        _buildStatCard(
          "Contamination",
          _contaminationRate,
          Icons.warning_amber_rounded,
          Colors.orange,
          unit: "%",
          isDouble: true,
        ),
        _buildStatCard(
          "Dominant Size",
          0,
          Icons.photo_size_select_small,
          Colors.purple,
          isText: true,
          textVal: _dominantSize,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    num value,
    IconData icon,
    Color color, {
    String unit = "",
    bool isDouble = false,
    bool isText = false,
    String textVal = "",
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isText
                  ? Text(
                      textVal,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                      ),
                    )
                  : Text(
                      "${isDouble ? value.toStringAsFixed(1) : value.toInt()}$unit",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                      ),
                    ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    _pieTouchedIndex = -1;
                    return;
                  }
                  _pieTouchedIndex =
                      pieTouchResponse.touchedSection!.touchedSectionIndex;
                });
              },
            ),
            sectionsSpace: 4,
            centerSpaceRadius: 40,
            sections: _buildPieSections(),
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final double total = (_petCount + _nonPetCount).toDouble();
    if (total == 0) return [];
    return List.generate(2, (i) {
      final isTouched = i == _pieTouchedIndex;
      final double fontSize = isTouched ? 20.0 : 14.0;
      final double radius = isTouched ? 60.0 : 50.0;
      if (i == 0)
        return PieChartSectionData(
          color: _bgGreen,
          value: _petCount.toDouble(),
          title: _petCount > 0 ? '${((_petCount / total) * 100).toInt()}%' : '',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      else
        return PieChartSectionData(
          color: _accentColor,
          value: _nonPetCount.toDouble(),
          title: _nonPetCount > 0
              ? '${((_nonPetCount / total) * 100).toInt()}%'
              : '',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
    });
  }

  Widget _buildInteractiveBarChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY:
              (_sizeDistribution.values.isEmpty
                  ? 0
                  : _sizeDistribution.values.reduce((a, b) => a > b ? a : b)) +
              2.0,
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  );
                  switch (value.toInt()) {
                    case 0:
                      return const Text('Small', style: style);
                    case 1:
                      return const Text('Std', style: style);
                    case 2:
                      return const Text('Large', style: style);
                    case 3:
                      return const Text('Fam', style: style);
                    case 4:
                      return const Text('Bulk', style: style);
                    default:
                      return const Text('');
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

  BarChartGroupData _makeGroupData(int x, double y) => BarChartGroupData(
    x: x,
    barRods: [
      BarChartRodData(
        toY: y,
        color: _bgGreen,
        width: 20,
        borderRadius: BorderRadius.circular(4),
      ),
    ],
  );

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
              const Text(
                "Clear PET Purity",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                "${_purityPercentage.toStringAsFixed(1)}%",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
