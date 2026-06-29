import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/scan_record.dart';
import '../../models/patient.dart';
import '../../core/theme.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/services/local_database.dart';

class ResultScreen extends StatefulWidget {
  final ScanRecord scan;

  const ResultScreen({super.key, required this.scan});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSharingPdf = false;

  Future<void> _sharePdf() async {
    setState(() => _isSharingPdf = true);
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      Map<String, dynamic>? doctorData;
      if (uid != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('doctors')
              .doc(uid)
              .get(const GetOptions(source: Source.serverAndCache));
          doctorData = doc.data();
        } catch (_) {}
      }
      
      Patient? patient;
      try {
        patient = LocalDatabase().getPatient(widget.scan.patientId);
        if (patient == null) {
          final patientDoc = await FirebaseFirestore.instance
              .collection('patients')
              .doc(widget.scan.patientId)
              .get(const GetOptions(source: Source.serverAndCache));
          if (patientDoc.exists) {
            patient = Patient.fromFirestore(patientDoc);
          }
        }
      } catch (_) {}

      await PdfReportService().shareReport(
        widget.scan,
        doctorData: doctorData,
        patient: patient,
      );
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF Generation Failed'),
            content: Text('Error details: $e\n\nPlease stop the application, run "flutter run" to rebuild it completely, and try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _getStatusColor(widget.scan.resultLabel);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Diagnostic Report',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () =>
              Navigator.popUntil(context, (route) => route.isFirst),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Dual Retinal Images Row (OS and OD)
                        _buildImagesRow(context),
                        const SizedBox(height: 16),

                        // 2. Patient Info Card
                        _buildPatientInfoCard(statusColor),
                        const SizedBox(height: 16),

                        // 3. Compact Metrics Row
                        _buildMetricsCard(statusColor),
                        const SizedBox(height: 16),

                        // 4. Diagnosis Result Card (With Left/Right Eye breakdown)
                        _buildDiagnosisCard(statusColor),
                        const SizedBox(height: 16),

                        // 5. Recommendations Cards (Eye-specific)
                        if (widget.scan.leftStage != null || widget.scan.leftImageUrl.isNotEmpty) ...[
                          _buildRecommendationsCard(
                            eyeLabel: 'LEFT EYE (OS) Guidance',
                            stage: widget.scan.leftStage,
                            confidence: widget.scan.leftConfidence,
                            resultLabel: widget.scan.leftResultLabel,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (widget.scan.rightStage != null || widget.scan.rightImageUrl.isNotEmpty) ...[
                          _buildRecommendationsCard(
                            eyeLabel: 'RIGHT EYE (OD) Guidance',
                            stage: widget.scan.rightStage,
                            confidence: widget.scan.rightConfidence,
                            resultLabel: widget.scan.rightResultLabel,
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Spacer(),
                        const SizedBox(height: 24),

                        // 6. Action Buttons (Always at bottom)
                        _buildActionButtons(context),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImagesRow(BuildContext context) {
    return Row(
      children: [
        // Left Eye (OS)
        Expanded(
          child: _buildEyeImageCard(
            context,
            eyeLabel: 'LEFT EYE (OS)',
            imageUrl: widget.scan.leftImageUrl,
            stageLabel: widget.scan.leftResultLabel ?? 'N/A',
            stage: widget.scan.leftStage,
            confidence: widget.scan.leftConfidence,
            eyeColor: _getStatusColor(widget.scan.leftResultLabel),
          ),
        ),
        const SizedBox(width: 16),
        // Right Eye (OD)
        Expanded(
          child: _buildEyeImageCard(
            context,
            eyeLabel: 'RIGHT EYE (OD)',
            imageUrl: widget.scan.rightImageUrl,
            stageLabel: widget.scan.rightResultLabel ?? 'N/A',
            stage: widget.scan.rightStage,
            confidence: widget.scan.rightConfidence,
            eyeColor: _getStatusColor(widget.scan.rightResultLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildEyeImageCard(
    BuildContext context, {
    required String eyeLabel,
    required String imageUrl,
    required String stageLabel,
    required int? stage,
    required double? confidence,
    required Color eyeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyeLabel,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => showFullScreenImage(context, imageUrl),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? (imageUrl.startsWith('http') || imageUrl.startsWith('https')
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholderIcon(Icons.remove_red_eye_outlined),
                            )
                          : Image.file(
                              File(imageUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholderIcon(Icons.broken_image_outlined),
                            ))
                      : _buildPlaceholderIcon(Icons.remove_red_eye_outlined),
                  
                  // Gradient Overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color(0x88000000)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Results overlay at the bottom
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: eyeColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            stage != null ? '$stageLabel (Stage $stage)' : stageLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        if (confidence != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Confidence: ${confidence.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderIcon(IconData icon) {
    return Container(
      color: const Color(0xFF1A1C1E),
      child: Center(
        child: Icon(
          icon,
          size: 40,
          color: Colors.white24,
        ),
      ),
    );
  }

  Widget _buildPatientInfoCard(Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: statusColor.withOpacity(0.12),
            child: Text(
              widget.scan.patientName.isEmpty
                  ? 'P'
                  : widget.scan.patientName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.scan.patientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Diabetic Retinopathy Dual Screening',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              'Max Confidence',
              '${widget.scan.confidence?.toStringAsFixed(1) ?? "0.0"}%',
              Icons.psychology_outlined,
              AppTheme.primaryBlue,
            ),
          ),
          Container(width: 1, height: 28, color: Colors.grey.shade100),
          Expanded(
            child: _buildMetricTile(
              'Overall Stage',
              'Stage ${widget.scan.stage ?? 0}',
              Icons.bar_chart_rounded,
              statusColor,
            ),
          ),
          Container(width: 1, height: 28, color: Colors.grey.shade100),
          Expanded(
            child: _buildMetricTile(
              'Scan Date',
              '${widget.scan.timestamp.day}/${widget.scan.timestamp.month}/${widget.scan.timestamp.year}',
              Icons.calendar_today_outlined,
              AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppTheme.textDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildDiagnosisCard(Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.05),
            statusColor.withOpacity(0.01),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Overall Diagnostic Result',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.scan.resultLabel ?? 'N/A',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: statusColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          _buildSeverityBar(statusColor),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildEyeDetailColumn(
                'Left Eye (OS)',
                widget.scan.leftResultLabel ?? 'N/A',
                widget.scan.leftConfidence,
                _getStatusColor(widget.scan.leftResultLabel),
              ),
              Container(width: 1, height: 36, color: Colors.grey.shade200),
              _buildEyeDetailColumn(
                'Right Eye (OD)',
                widget.scan.rightResultLabel ?? 'N/A',
                widget.scan.rightConfidence,
                _getStatusColor(widget.scan.rightResultLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEyeDetailColumn(String eye, String diagnosis, double? conf, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            eye,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            diagnosis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
          if (conf != null) ...[
            const SizedBox(height: 2),
            Text(
              'Confidence: ${conf.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSeverityBar(Color activeColor) {
    final shortLabels = ['No DR', 'Mild', 'Mod.', 'Sev.', 'PDR'];
    final colors = [
      AppTheme.successGreen,
      Colors.lightGreen,
      AppTheme.warningOrange,
      Colors.orange,
      AppTheme.errorRed,
    ];
    final currentStage = widget.scan.stage ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: List.generate(5, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                height: 6,
                decoration: BoxDecoration(
                  color: i <= currentStage ? colors[i] : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final isCurrent = i == currentStage;
            return Expanded(
              child: Center(
                child: Text(
                  shortLabels[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? colors[i] : AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Share PDF Report button (prominent, full-width)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSharingPdf ? null : _sharePdf,
            icon: _isSharingPdf
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: Text(_isSharingPdf ? 'Preparing Report...' : 'Share PDF Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: const Text('Home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('New Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(String? label) {
    switch (label) {
      case 'No DR':
        return AppTheme.successGreen;
      case 'Mild':
        return Colors.lightGreen;
      case 'Moderate':
        return AppTheme.warningOrange;
      case 'Severe':
        return Colors.orange;
      case 'Proliferative':
        return AppTheme.errorRed;
      default:
        return AppTheme.primaryBlue;
    }
  }

  Widget _buildRecommendationsCard({
    required String eyeLabel,
    required int? stage,
    required double? confidence,
    required String? resultLabel,
  }) {
    final Color color = _getStatusColor(resultLabel);
    final recommendations = ScanRecord.getRecommendationsForStage(stage ?? 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        eyeLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Stage ${stage ?? 0} (${confidence?.toStringAsFixed(1) ?? "0"}%)',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.map((rec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5, right: 8),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rec,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textDark,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
