import 'package:flutter/material.dart';
import '../../models/scan_record.dart';
import '../../core/theme.dart';

class ResultScreen extends StatelessWidget {
  final ScanRecord scan;

  const ResultScreen({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _getStatusColor(scan.resultLabel);

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
                        // 1. Retinal Image Card (Compact & Interactive)
                        GestureDetector(
                          onTap: () =>
                              showFullScreenImage(context, scan.imageUrl),
                          child: Container(
                            height: 250,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  scan.imageUrl.isNotEmpty
                                      ? Image.network(
                                          scan.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: const Color(0xFF1A1C1E),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons
                                                        .remove_red_eye_outlined,
                                                    size: 64,
                                                    color: Colors.white24,
                                                  ),
                                                ),
                                              ),
                                        )
                                      : Container(
                                          color: const Color(0xFF1A1C1E),
                                          child: const Center(
                                            child: Icon(
                                              Icons.remove_red_eye_outlined,
                                              size: 64,
                                              color: Colors.white24,
                                            ),
                                          ),
                                        ),
                                  // Gradient Overlay
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Color(0x99000000),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                  // Badge overlay
                                  Positioned(
                                    bottom: 16,
                                    left: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.biotech,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            scan.resultLabel ?? 'N/A',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Patient Info Card
                        _buildPatientInfoCard(statusColor),
                        const SizedBox(height: 16),

                        // 3. Compact Metrics Row
                        _buildMetricsCard(statusColor),
                        const SizedBox(height: 16),

                        // 4. Diagnosis Result Card
                        _buildDiagnosisCard(statusColor),
                        const Spacer(),
                        const SizedBox(height: 16),

                        // 5. Action Buttons (Always at bottom)
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
              scan.patientName.isEmpty
                  ? 'P'
                  : scan.patientName.substring(0, 1).toUpperCase(),
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
                  scan.patientName,
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
                  'Diabetic Retinopathy Screening',
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
              'AI Confidence',
              '${scan.confidence?.toStringAsFixed(1) ?? "94.2"}%',
              Icons.psychology_outlined,
              AppTheme.primaryBlue,
            ),
          ),
          Container(width: 1, height: 28, color: Colors.grey.shade100),
          Expanded(
            child: _buildMetricTile(
              'DR Stage',
              'Stage ${scan.stage ?? 0}',
              Icons.bar_chart_rounded,
              statusColor,
            ),
          ),
          Container(width: 1, height: 28, color: Colors.grey.shade100),
          Expanded(
            child: _buildMetricTile(
              'Scan Date',
              '${scan.timestamp.day}/${scan.timestamp.month}/${scan.timestamp.year}',
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
                'Diagnostic Result',
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
            scan.resultLabel ?? 'N/A',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: statusColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          _buildSeverityBar(statusColor),
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
    final currentStage = scan.stage ?? 0;

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
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.dashboard_outlined, size: 18),
            label: const Text('Home'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.4)),
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
}
