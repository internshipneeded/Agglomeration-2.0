import 'dart:convert';
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
  double _estimatedRevenue = 0.0;
  double _qualityGrade = 0.0;
  double _contaminationRate = 0.0;

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

  // --- 1. DATA FETCHING ---
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

    // Reset
    _totalBottles = 0;
    _estimatedRevenue = 0;
    _petCount = 0;
    _nonPetCount = 0;
    _sizeDistribution = {'Small': 0, 'Standard': 0, 'Large': 0, 'Family': 0, 'Bulk': 0};

    for (var scan in scans) {
      _totalBottles += scan.totalBottles;
      _estimatedRevenue += scan.totalValue;

      // 1. Material & Quality
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

      // 2. Size
      var sizeDet = scan.detections.firstWhere(
              (d) => d.source == 'ImmortalTree_Size',
          orElse: () => Detection(source: 'Unknown', label: '', confidence: 0, brand: '', color: '', material: '')
      );

      if (sizeDet.source != 'Unknown') {
        String sizeCategory = _parseSize(sizeDet.meta?['detected_size']);
        _sizeDistribution[sizeCategory] = (_sizeDistribution[sizeCategory] ?? 0) + 1;
      }
    }

    if (_totalBottles > 0) {
      _qualityGrade = totalClearPet / _totalBottles;
      _contaminationRate = _nonPetCount / (_petCount + _nonPetCount);
    } else {
      _qualityGrade = 0.0;
      _contaminationRate = 0.0;
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

  // --- 2. PDF GENERATION (FIXED) ---
  Future<void> _generateAndExportPdf() async {
    final pdf = pw.Document();

    // Use built-in fonts for speed/offline reliability
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final PdfColor primaryColor = PdfColor.fromInt(0xFF537A68);
    final PdfColor lightBg = PdfColor.fromInt(0xFFF7F9F8);
    final PdfColor textColor = PdfColor.fromInt(0xFF2C3E36);

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
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("PET PERPLEXITY", style: pw.TextStyle(font: fontBold, fontSize: 20, color: primaryColor, letterSpacing: 2)),
                  pw.Text("Agglomeration 2.0 Report", style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text("DATE GENERATED", style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey500)),
                  pw.Text(DateTime.now().toString().split(' ')[0], style: pw.TextStyle(font: fontBold, fontSize: 12, color: textColor)),
                ])
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: primaryColor, thickness: 1.5),
            pw.SizedBox(height: 20),

            // Summary
            pw.Text("BATCH OVERVIEW", style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600, letterSpacing: 1.2)),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfStatCard("Total Items", "$_totalBottles", PdfColors.blue50, PdfColors.blue700, fontBold, font),
                _buildPdfStatCard("Est. Revenue", "Rs. ${_estimatedRevenue.toStringAsFixed(0)}", PdfColors.green50, PdfColors.green700, fontBold, font),
                _buildPdfStatCard("Clear Purity", "${(_qualityGrade * 100).toStringAsFixed(1)}%", PdfColors.teal50, PdfColors.teal700, fontBold, font),
                _buildPdfStatCard("Contamination", "${(_contaminationRate * 100).toStringAsFixed(1)}%", PdfColors.orange50, PdfColors.orange700, fontBold, font),
              ],
            ),
            pw.SizedBox(height: 30),

            // Material Table (WITH FIX)
            pw.Text("MATERIAL COMPOSITION", style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600, letterSpacing: 1.2)),
            pw.SizedBox(height: 10),
            _buildVisualTable(
              headers: ['Material Type', 'Count', 'Distribution'],
              data: [
                ['PET Plastic', '$_petCount', _totalBottles > 0 ? (_petCount / _totalBottles) : 0.0, PdfColors.green],
                ['Non-PET', '$_nonPetCount', _totalBottles > 0 ? (_nonPetCount / _totalBottles) : 0.0, PdfColors.redAccent],
              ],
              font: font,
              fontBold: fontBold,
            ),

            pw.SizedBox(height: 30),

            // Size Table
            pw.Text("SIZE CLASSIFICATION", style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600, letterSpacing: 1.2)),
            pw.SizedBox(height: 10),
            pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
                // Use explicit column widths if needed, but simple text tables usually auto-size fine
                children: [
                  pw.TableRow(decoration: pw.BoxDecoration(color: lightBg), children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Size Category", style: pw.TextStyle(font: fontBold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Count", style: pw.TextStyle(font: fontBold, fontSize: 10))),
                  ]),
                  ..._sizeDistribution.entries.map((e) => pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(e.key, style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${e.value}', style: pw.TextStyle(fontSize: 10))),
                  ])).toList()
                ]
            ),

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 5),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("Generated by Pet Perplexity AI", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              pw.Text("Page 1 of 1", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ])
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'pet_perplexity_report.pdf');
  }

  pw.Widget _buildPdfStatCard(String label, String value, PdfColor bg, PdfColor accent, pw.Font fontBold, pw.Font font) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 16, color: accent)),
        pw.SizedBox(height: 4),
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
      ]),
    );
  }

  // 🔴 FIXED: Added columnWidths to prevent "Unbounded Width" error for Expanded
  pw.Widget _buildVisualTable({
    required List<String> headers,
    required List<List<dynamic>> data,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    return pw.Table(
        border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
        // ⬇️ THIS IS THE FIX: Explicitly define width for the flexible column
        columnWidths: {
          0: const pw.FlexColumnWidth(3), // Material Name
          1: const pw.FixedColumnWidth(50), // Count
          2: const pw.FlexColumnWidth(4), // Progress Bar (Needs bounded width)
        },
        children: [
          pw.TableRow(
              children: headers.map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(h, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700))
              )).toList()
          ),
          ...data.map((row) {
            final String label = row[0];
            final String count = row[1];
            final double percentage = row[2];
            final PdfColor barColor = row[3];

            return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text(label, style: pw.TextStyle(fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text(count, style: pw.TextStyle(fontSize: 10))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8),
                      child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: (percentage * 100).toInt(),
                              child: pw.Container(height: 6, decoration: pw.BoxDecoration(color: barColor, borderRadius: pw.BorderRadius.circular(4))),
                            ),
                            pw.Expanded(
                              flex: 100 - (percentage * 100).toInt(),
                              child: pw.Container(height: 6, color: PdfColors.grey100),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Text("${(percentage * 100).toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          ]
                      )
                  ),
                ]
            );
          }).toList()
        ]
    );
  }

  // --- 3. FLUTTER UI ---
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
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating PDF..."), duration: Duration(seconds: 1)));
              try {
                await _generateAndExportPdf();
              } catch (e) {
                if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Failed: $e"), backgroundColor: Colors.red));
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _bgGreen))
          : RefreshIndicator(
        onRefresh: () async { setState(() => _isLoading = true); await _fetchAndCalculateStats(); },
        color: _bgGreen,
        child: _totalBottles == 0 ? _buildEmptyState() : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Last Updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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
    );
  }

  // ... (Keep existing UI widgets below: _buildSectionHeader, _buildSummaryGrid, _buildStatCard, _buildInteractivePieChart, _buildPieSections, _buildInteractiveBarChart, _buildQualityCard, _buildEmptyState) ...
  // [Paste your existing helper widget methods here as they were in the previous correct version]
  // Note: I am omitting them here for brevity since you already have them working, but make sure they are included in your final file.

  // Example of one to ensure you have context:
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [Icon(icon, size: 20, color: _bgGreen), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor))]);
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[300]), const SizedBox(height: 16), Text("No Data", style: TextStyle(fontSize: 18, color: Colors.grey[600]))]));
  }

  Widget _buildSummaryGrid() {
    return GridView.count(
      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.6,
      children: [
        _buildStatCard("Total Bottles", _totalBottles, Icons.recycling, Colors.blue),
        _buildStatCard("Revenue", _estimatedRevenue, Icons.currency_rupee, _bgGreen, isCurrency: true),
        _buildStatCard("Quality", _qualityGrade * 100, Icons.verified, _accentColor, unit: "%", isDouble: true),
        _buildStatCard("Contamination", _contaminationRate * 100, Icons.warning_amber_rounded, Colors.orange, unit: "%", isDouble: true),
      ],
    );
  }

  // (Include _buildStatCard, _buildInteractivePieChart, _buildInteractiveBarChart, etc. here)
  Widget _buildStatCard(String label, num value, IconData icon, Color color, {String unit = "", bool isCurrency = false, bool isDouble = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isCurrency ? "₹${value.toStringAsFixed(0)}" : "${isDouble ? value.toStringAsFixed(1) : value.toInt()}$unit", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textColor)), Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))])]),
    );
  }

  Widget _buildInteractivePieChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[100]!), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
      child: SizedBox(height: 200, child: PieChart(PieChartData(pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) { setState(() { if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) { _pieTouchedIndex = -1; return; } _pieTouchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex; }); }), sectionsSpace: 4, centerSpaceRadius: 40, sections: _buildPieSections()))),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final double total = (_petCount + _nonPetCount).toDouble();
    if (total == 0) return [];
    return List.generate(2, (i) {
      final isTouched = i == _pieTouchedIndex;
      final double fontSize = isTouched ? 20.0 : 14.0;
      final double radius = isTouched ? 60.0 : 50.0;
      if (i == 0) return PieChartSectionData(color: _bgGreen, value: _petCount.toDouble(), title: _petCount > 0 ? '${((_petCount / total) * 100).toInt()}%' : '', radius: radius, titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white));
      else return PieChartSectionData(color: _accentColor, value: _nonPetCount.toDouble(), title: _nonPetCount > 0 ? '${((_nonPetCount / total) * 100).toInt()}%' : '', radius: radius, titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white));
    });
  }

  Widget _buildLegendItem(String text, Color color, int count) {
    return Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)), Text("$count Units", style: TextStyle(color: _textColor, fontWeight: FontWeight.bold))])]);
  }

  Widget _buildInteractiveBarChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20)),
      child: BarChart(BarChartData(alignment: BarChartAlignment.spaceAround, maxY: (_sizeDistribution.values.isEmpty ? 0 : _sizeDistribution.values.reduce((a, b) => a > b ? a : b)) + 2.0, gridData: const FlGridData(show: false), titlesData: FlTitlesData(leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) { const style = TextStyle(fontSize: 10, fontWeight: FontWeight.bold); switch (value.toInt()) { case 0: return const Text('Small', style: style); case 1: return const Text('Std', style: style); case 2: return const Text('Large', style: style); case 3: return const Text('Fam', style: style); case 4: return const Text('Bulk', style: style); default: return const Text(''); } }))), borderData: FlBorderData(show: false), barGroups: [_makeGroupData(0, _sizeDistribution['Small']!.toDouble()), _makeGroupData(1, _sizeDistribution['Standard']!.toDouble()), _makeGroupData(2, _sizeDistribution['Large']!.toDouble()), _makeGroupData(3, _sizeDistribution['Family']!.toDouble()), _makeGroupData(4, _sizeDistribution['Bulk']!.toDouble())])),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y) => BarChartGroupData(x: x, barRods: [BarChartRodData(toY: y, color: _bgGreen, width: 20, borderRadius: BorderRadius.circular(4))]);

  Widget _buildQualityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [_textColor, const Color(0xFF1A2822)]), borderRadius: BorderRadius.circular(24)),
      child: Row(children: [const Icon(Icons.verified, color: Colors.white, size: 28), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Batch Quality Grade", style: TextStyle(color: Colors.white70, fontSize: 12)), Text((_qualityGrade * 100) > 80 ? "Gold Standard" : "Standard Grade", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))])]),
    );
  }
}