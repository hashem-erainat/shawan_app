import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../models/scan_record.dart';
import '../../models/patient.dart';

class PdfReportService {
  static final PdfReportService _instance = PdfReportService._internal();
  factory PdfReportService() => _instance;
  PdfReportService._internal();

  static const PdfColor _primaryBlue = PdfColor.fromInt(0xFF1565C0);
  static const PdfColor _bgLight = PdfColor.fromInt(0xFFF5F7FA);
  static const PdfColor _textDark = PdfColor.fromInt(0xFF1A2340);
  static const PdfColor _textSecondary = PdfColor.fromInt(0xFF6B7A99);
  static const PdfColor _white = PdfColors.white;
  static const PdfColor _borderGrey = PdfColor.fromInt(0xFFE0E6F0);

  PdfColor _getDRColor(String? label) {
    switch (label) {
      case 'No DR':
        return const PdfColor.fromInt(0xFF43A047);
      case 'Mild':
        return const PdfColor.fromInt(0xFF7CB342);
      case 'Moderate':
        return const PdfColor.fromInt(0xFFFF8F00);
      case 'Severe':
        return const PdfColor.fromInt(0xFFE65100);
      case 'Proliferative':
        return const PdfColor.fromInt(0xFFC62828);
      default:
        return _primaryBlue;
    }
  }

  bool _isArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  Future<Uint8List> generateReport(ScanRecord scan, {Map<String, dynamic>? doctorData, Patient? patient}) async {
    pw.Document pdf;
    try {
      final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
      final fontBoldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
      final fontRegular = pw.Font.ttf(fontData);
      final fontBold = pw.Font.ttf(fontBoldData);

      pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
      );
    } catch (e) {
      // ignore: avoid_print
      print('WARNING: Could not load Cairo fonts, falling back to default Helvetica fonts: $e');
      pdf = pw.Document();
    }

    pw.MemoryImage? leftImage;
    pw.MemoryImage? rightImage;

    Future<Uint8List?> loadImageBytes(String pathOrUrl) async {
      if (pathOrUrl.isEmpty) return null;
      try {
        if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
          final response = await http.get(Uri.parse(pathOrUrl)).timeout(const Duration(seconds: 8));
          if (response.statusCode == 200) {
            return response.bodyBytes;
          }
        } else {
          final file = File(pathOrUrl);
          if (file.existsSync()) {
            return await file.readAsBytes();
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('WARNING: Failed to load image bytes for $pathOrUrl: $e');
      }
      return null;
    }

    final leftBytes = await loadImageBytes(scan.leftImageUrl);
    if (leftBytes != null) {
      leftImage = pw.MemoryImage(leftBytes);
    }
    
    final rightBytes = await loadImageBytes(scan.rightImageUrl);
    if (rightBytes != null) {
      rightImage = pw.MemoryImage(rightBytes);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              pw.SizedBox(height: 12),
              _buildDataSection(scan, doctorData, patient),
              pw.SizedBox(height: 12),
              _buildImagesSection(scan, leftImage, rightImage),
              pw.SizedBox(height: 12),
              _buildDiagnosisSection(scan),
              pw.SizedBox(height: 12),
              _buildTipsSection(scan),
              pw.Spacer(),
              _buildSignatures(),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildHeader() {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            'Diabetic Retinopathy Report',
            style: pw.TextStyle(
              color: _primaryBlue,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'BIOMEDICAL ENGINEERING',
            style: pw.TextStyle(
              color: _primaryBlue,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _primaryBlue, thickness: 1.5),
      ],
    );
  }

  pw.Widget _buildDataSection(ScanRecord scan, Map<String, dynamic>? doctorData, Patient? patient) {
    final bool isArName = _isArabic(scan.patientName);
    
    final rawDocName = doctorData?['name'] ?? 'Unknown';
    final doctorName = rawDocName.startsWith('Dr.') || rawDocName.startsWith('Dr ')
        ? rawDocName
        : 'Dr. $rawDocName';
    final doctorPhone = doctorData?['phone'] ?? 'N/A';
    final doctorEmail = doctorData?['email'] ?? 'N/A';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PATIENT DATA:',
          style: pw.TextStyle(
            color: _primaryBlue,
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _dataField('Full Name', scan.patientName, isArabicValue: isArName),
            _dataField('Patient ID', scan.patientId),
            _dataField('Exam Date', DateFormat('dd/MM/yyyy').format(scan.timestamp)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _dataField('Age', patient?.age?.toString() ?? 'N/A'),
            _dataField('Gender', patient?.gender ?? 'N/A'),
            pw.Expanded(child: pw.SizedBox()),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'DOCTOR DATA:',
          style: pw.TextStyle(
            color: _primaryBlue,
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _dataField('Doctor Name', doctorName),
            _dataField('Phone', doctorPhone),
            _dataField('Email', doctorEmail),
          ],
        ),
      ],
    );
  }

  pw.Widget _dataField(String label, String value, {bool isArabicValue = false}) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: _textSecondary,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: _textDark,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
            textDirection: isArabicValue ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildImagesSection(ScanRecord scan, pw.MemoryImage? leftImage, pw.MemoryImage? rightImage) {
    final leftLabel = scan.leftStage != null 
        ? 'Left Eye (OS) - Stage ${scan.leftStage} (${scan.leftConfidence?.toStringAsFixed(1) ?? "0"}%)'
        : 'Left Eye (OS)';
    final rightLabel = scan.rightStage != null 
        ? 'Right Eye (OD) - Stage ${scan.rightStage} (${scan.rightConfidence?.toStringAsFixed(1) ?? "0"}%)'
        : 'Right Eye (OD)';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'IMAGES :',
          style: pw.TextStyle(
            color: _primaryBlue,
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(
              child: _imageCard(leftLabel, leftImage),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: _imageCard(rightLabel, rightImage),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _imageCard(String label, pw.MemoryImage? image) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          height: 130,
          width: double.infinity,
          decoration: pw.BoxDecoration(
            color: _bgLight,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _borderGrey, width: 1),
          ),
          child: image != null
              ? pw.ClipRRect(
                  horizontalRadius: 8,
                  verticalRadius: 8,
                  child: pw.Image(
                    image,
                    fit: pw.BoxFit.contain,
                  ),
                )
              : pw.Center(
                  child: pw.Text(
                    'Image Unavailable',
                    style: pw.TextStyle(color: _textSecondary, fontSize: 8),
                  ),
                ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            color: _textSecondary,
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildDiagnosisSection(ScanRecord scan) {
    final label = scan.resultLabel ?? 'N/A';
    final stage = scan.stage;
    final confidence = scan.confidence;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DIAGNOSIS',
          style: pw.TextStyle(
            color: _primaryBlue,
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(
              child: _diagnosisPill('Overall Severity', label),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _diagnosisPill('Overall Stage', stage != null ? 'Stage $stage' : 'N/A'),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _diagnosisPill('Max Accuracy', confidence != null ? '${confidence.toStringAsFixed(1)}%' : 'N/A'),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              child: _eyeDetailRow(
                'Left Eye (OS)',
                scan.leftResultLabel ?? 'N/A',
                scan.leftStage,
                scan.leftConfidence,
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: _eyeDetailRow(
                'Right Eye (OD)',
                scan.rightResultLabel ?? 'N/A',
                scan.rightStage,
                scan.rightConfidence,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _eyeDetailRow(String eye, String diagnosis, int? stage, double? confidence) {
    final stageStr = stage != null ? ' (Stage $stage)' : '';
    final confStr = confidence != null ? ' - ${confidence.toStringAsFixed(1)}%' : '';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGrey, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
        color: _bgLight,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            eye,
            style: pw.TextStyle(
              color: _textSecondary,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '$diagnosis$stageStr$confStr',
            style: pw.TextStyle(
              color: _textDark,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _diagnosisPill(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFE8F0FE),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: _primaryBlue,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: _primaryBlue,
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTipsSection(ScanRecord scan) {
    final leftRecs = scan.leftStage != null || scan.leftImageUrl.isNotEmpty
        ? ScanRecord.getRecommendationsForStage(scan.leftStage ?? 0)
        : null;
    final rightRecs = scan.rightStage != null || scan.rightImageUrl.isNotEmpty
        ? ScanRecord.getRecommendationsForStage(scan.rightStage ?? 0)
        : null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TIPS:',
          style: pw.TextStyle(
            color: _primaryBlue,
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (leftRecs != null)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Left Eye (OS) Tips:',
                      style: pw.TextStyle(
                        color: _primaryBlue,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    ...List.generate(leftRecs.length, (index) {
                      return _tipsRow(index + 1, leftRecs[index]);
                    }),
                  ],
                ),
              ),
            if (leftRecs != null && rightRecs != null)
              pw.SizedBox(width: 16),
            if (rightRecs != null)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Right Eye (OD) Tips:',
                      style: pw.TextStyle(
                        color: _primaryBlue,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    ...List.generate(rightRecs.length, (index) {
                      return _tipsRow(index + 1, rightRecs[index]);
                    }),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _tipsRow(int num, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 10,
            child: pw.Text(
              '$num.',
              style: pw.TextStyle(
                color: _textDark,
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(
                color: _textDark,
                fontSize: 7.5,
                lineSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatures() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _signatureLine('ENG.Ahmad Shahwan'),
        _signatureLine('ENG.Yousef Shuaybi'),
        _signatureLine('ENG.Baraa Owis'),
      ],
    );
  }

  pw.Widget _signatureLine(String name) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Container(
            width: 120,
            height: 0.5,
            color: _textSecondary,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            name,
            style: pw.TextStyle(
              color: _textDark,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Generates the PDF and saves it locally. Returns the File or null on failure.
  Future<File?> saveReportLocally(ScanRecord scan, {Map<String, dynamic>? doctorData, Patient? patient}) async {
    try {
      final bytes = await generateReport(scan, doctorData: doctorData, patient: patient);
      final dir = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${dir.path}/oscope_reports');
      if (!reportsDir.existsSync()) {
        reportsDir.createSync(recursive: true);
      }
      final file = File(
        '${reportsDir.path}/Oscope_Report_${scan.patientId}_${scan.id}.pdf',
      );
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      // ignore: avoid_print
      print('WARNING: Failed to save PDF report: $e');
      rethrow;
    }
  }

  /// Opens the native share sheet for the scan report PDF.
  Future<void> shareReport(ScanRecord scan, {Map<String, dynamic>? doctorData, Patient? patient}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/oscope_reports/Oscope_Report_${scan.patientId}_${scan.id}.pdf';
      File file = File(filePath);
      
      // Always regenerate PDF to make sure doctorData and patient updates are included
      final saved = await saveReportLocally(scan, doctorData: doctorData, patient: patient);
      if (saved == null) {
        throw Exception("Failed to generate and save PDF file.");
      }
      file = saved;

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Oscope DR Report - ${scan.patientName}',
        text: 'Diabetic Retinopathy report for ${scan.patientName} '
            '(${DateFormat('dd/MM/yyyy').format(scan.timestamp)}) by Oscope.',
      );
    } catch (e) {
      // ignore: avoid_print
      print('ERROR: Could not share PDF: $e');
      rethrow;
    }
  }
}
