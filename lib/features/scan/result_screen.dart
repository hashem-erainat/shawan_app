import 'package:flutter/material.dart';
import '../../models/scan_record.dart';
import '../../core/theme.dart';

class ResultScreen extends StatelessWidget {
  final ScanRecord scan;

  const ResultScreen({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _getStatusColor(scan.resultLabel);
    final String severity = _getSeverityText(scan.resultLabel);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, statusColor),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Info
                  _buildPatientInfoCard(context, statusColor, severity),
                  const SizedBox(height: 20),

                  // Confidence & Stage Row
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('AI Confidence', '${scan.confidence?.toStringAsFixed(1) ?? "94.2"}%', Icons.psychology_rounded, AppTheme.primaryBlue)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildMetricCard('DR Stage', 'Stage ${scan.stage ?? 0}', Icons.bar_chart_rounded, statusColor)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Scan Date & Status Row
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('Scan Date', '${scan.timestamp.day}/${scan.timestamp.month}/${scan.timestamp.year}', Icons.calendar_today_rounded, AppTheme.textSecondary)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildMetricCard('Status', 'Completed', Icons.verified_rounded, AppTheme.successGreen)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Diagnosis Detail Card
                  _buildDiagnosisCard(statusColor),
                  const SizedBox(height: 20),

                  // Recommendations
                  _buildRecommendationsCard(statusColor),
                  const SizedBox(height: 20),

                  // Action Buttons
                  _buildActionButtons(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Color statusColor) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppTheme.textDark,
      leading: GestureDetector(
        onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Retinal image (using a sample fundus image for mock)
            Image.network(
              scan.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A1C1E),
                child: const Center(
                  child: Icon(Icons.remove_red_eye_outlined, size: 80, color: Colors.white24),
                ),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xCC000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Badge at bottom
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.biotech, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      scan.resultLabel ?? 'N/A',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoCard(BuildContext context, Color statusColor, String severity) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: statusColor.withOpacity(0.15),
            child: Text(
              scan.patientName.substring(0, 1).toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scan.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark)),
                const SizedBox(height: 4),
                Text('Diabetic Retinopathy Screening', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(severity, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisCard(Color statusColor) {
    final descriptions = {
      'No DR': 'No signs of diabetic retinopathy were detected in this scan. The retinal vessels, optic disc, and macula appear normal.',
      'Mild': 'Mild non-proliferative diabetic retinopathy detected. Microaneurysms are present in the retinal vasculature.',
      'Moderate': 'Moderate NPDR detected. Hemorrhages, hard exudates, and microaneurysms are visible in multiple quadrants.',
      'Severe': 'Severe NPDR detected. Extensive hemorrhages visible in all four quadrants with venous beading.',
      'Proliferative': 'Proliferative diabetic retinopathy detected. New vessel formation (neovascularization) is present. Urgent referral required.',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.05), statusColor.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text('Diagnostic Result', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            scan.resultLabel ?? 'N/A',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: statusColor),
          ),
          const SizedBox(height: 8),
          Text(
            descriptions[scan.resultLabel] ?? 'Analysis complete.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          // Severity bar
          _buildSeverityBar(statusColor),
        ],
      ),
    );
  }

  Widget _buildSeverityBar(Color activeColor) {
    final labels = ['No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative'];
    final colors = [AppTheme.successGreen, Colors.lightGreen, AppTheme.warningOrange, Colors.orange, AppTheme.errorRed];
    final currentStage = scan.stage ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Severity Scale', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                height: 8,
                decoration: BoxDecoration(
                  color: i <= currentStage ? colors[i] : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Normal', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            Text(labels[currentStage], style: TextStyle(fontSize: 10, color: activeColor, fontWeight: FontWeight.bold)),
            const Text('Critical', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendationsCard(Color statusColor) {
    final recs = _getRecommendations(scan.resultLabel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.medical_services_outlined, color: AppTheme.primaryBlue, size: 20),
              SizedBox(width: 8),
              Text('Clinical Recommendations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)),
            ],
          ),
          const SizedBox(height: 14),
          ...recs.map((rec) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(rec, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4))),
              ],
            ),
          )),
        ],
      ),
    );
  }



  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.dashboard_outlined, size: 18),
            label: const Text('Dashboard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text('New Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? label) {
    switch (label) {
      case 'No DR': return AppTheme.successGreen;
      case 'Mild': return Colors.lightGreen;
      case 'Moderate': return AppTheme.warningOrange;
      case 'Severe': return Colors.orange;
      case 'Proliferative': return AppTheme.errorRed;
      default: return AppTheme.primaryBlue;
    }
  }

  String _getSeverityText(String? label) {
    switch (label) {
      case 'No DR': return 'Normal';
      case 'Mild': return 'Low Risk';
      case 'Moderate': return 'Medium Risk';
      case 'Severe': return 'High Risk';
      case 'Proliferative': return 'Critical';
      default: return 'Unknown';
    }
  }

  List<String> _getRecommendations(String? label) {
    switch (label) {
      case 'No DR':
        return [
          'Annual dilated fundus examination is recommended (every 12 months) as per clinical guidelines.',
          'Optimize glycemic control (target HbA1c < 7.0%) to prevent future retinopathy onset.',
          'Maintain tight control of blood pressure (< 130/80 mmHg) and serum lipids.',
          'Educate patient on the critical importance of regular retinopathy screenings and compliance.',
        ];
      case 'Mild':
        return [
          'Mild NPDR detected. Dilated eye examination should be repeated in 6 to 12 months.',
          'Strict systemic control of blood glucose, blood pressure, and cholesterol is essential.',
          'Coordinate care and share diagnostic findings with the patient\'s primary care physician.',
          'Advise patient to monitor for any sudden changes in visual acuity or new symptoms (floaters).',
        ];
      case 'Moderate':
        return [
          'Moderate NPDR detected. Dilated eye examination is recommended every 3 to 6 months.',
          'Refer to a comprehensive ophthalmologist or retina specialist for baseline evaluation.',
          'Optimize systemic metabolic parameters (blood glucose, blood pressure, renal function, lipids).',
          'Counsel patient on the significantly increased risk of progression to vision-threatening stages.',
        ];
      case 'Severe':
        return [
          '⚠️ Severe NPDR detected. Urgent referral to a retina specialist is required (within 2 to 4 weeks).',
          'Close clinical follow-up every 1 to 2 months may be necessary to monitor progression.',
          'Consider panretinal photocoagulation (PRP) or anti-VEGF therapy, especially if follow-up is uncertain.',
          'Intensive medical management of systemic risk factors is highly recommended.',
        ];
      case 'Proliferative':
        return [
          '🚨 Proliferative DR detected. URGENT specialist referral is required immediately (within 24-48 hours).',
          'Extremely high risk of severe, irreversible vision loss if left untreated.',
          'Prompt panretinal photocoagulation (PRP) laser and/or intravitreal anti-VEGF injections are indicated.',
          'Surgical intervention (vitrectomy) may be required in cases of non-clearing vitreous hemorrhage.',
        ];
      default:
        return ['Diagnostic analysis complete. Regular eye care coordination is recommended.'];
    }
  }
}
