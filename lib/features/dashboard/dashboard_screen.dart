import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/services/firebase_service.dart';
import '../../models/scan_record.dart';
import '../scan/capture_screen.dart';
import '../scan/result_screen.dart';
import '../patients/patient_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const DashboardHome(),
      const PatientListScreen(),
      const _SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20)],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: AppTheme.textSecondary,
          backgroundColor: Colors.transparent,
          elevation: 0,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Patients'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Start New Scan Banner
                _buildStartScanBanner(context),
                const SizedBox(height: 24),

                // Quick Stats Grid
                _buildStatsSection(context),
                const SizedBox(height: 24),

                // Quick Actions
                _buildQuickActions(context),
                const SizedBox(height: 24),

                // Recent Scans
                _buildRecentScansSection(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Good Morning 👋', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
                    Text('Dr. Ahmed Atif', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
                  ],
                ),
              ),
              // Notification bell
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: Badge(
                    label: const Text('2'),
                    child: const Icon(Icons.notifications_outlined, color: AppTheme.textDark),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                foregroundImage: const NetworkImage('https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?ixlib=rb-4.0.3&auto=format&fit=crop&w=150&q=80'),
                child: const Text('AA', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartScanBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptureScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E40AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('AI-Powered', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Start New\nRetinal Scan',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Instant diabetic retinopathy detection',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB), size: 16),
                        SizedBox(width: 6),
                        Text('Capture Now', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Patients', '1,240', Icons.people_outline_rounded, AppTheme.primaryBlue, '+12 this month')),
            const SizedBox(width: 14),
            Expanded(child: _buildStatCard('Scans Today', '28', Icons.biotech_rounded, const Color(0xFF7C3AED), '+5 vs yesterday')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildStatCard('High Risk', '3', Icons.warning_amber_rounded, AppTheme.errorRed, 'Require attention', isAlert: true)),
            const SizedBox(width: 14),
            Expanded(child: _buildStatCard('Avg. Accuracy', '94.8%', Icons.analytics_rounded, AppTheme.successGreen, 'AI model score')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isAlert ? Border.all(color: color.withOpacity(0.3), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              if (isAlert)
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: AppTheme.errorRed, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: AppTheme.textDark, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildActionButton(context, 'New Scan', Icons.add_a_photo_rounded, const Color(0xFF2563EB), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptureScreen()));
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(context, 'Patients', Icons.person_search_rounded, const Color(0xFF7C3AED), () {})),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(context, 'Reports', Icons.assessment_rounded, const Color(0xFF059669), () {})),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(context, 'History', Icons.history_rounded, const Color(0xFFD97706), () {})),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentScansSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Scans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark)),
            TextButton(
              onPressed: () {},
              child: const Text('View All', style: TextStyle(color: AppTheme.primaryBlue, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<ScanRecord>>(
          stream: FirebaseService().getRecentScans(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyScansCard();
            }
            return _buildScanList(context, snapshot.data!);
          },
        ),
      ],
    );
  }

  Widget _buildEmptyScansCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 56, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          const Text('No scans recorded yet', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Perform your first retinal scan', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildScanList(BuildContext context, List<ScanRecord> scans) {
    return Column(
      children: scans.take(5).toList().asMap().entries.map((entry) {
        final scan = entry.value;
        final bool isCompleted = scan.status == ScanStatus.completed;
        final Color statusColor = _getStatusColor(scan.resultLabel);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.12),
              child: Text(
                scan.patientName.substring(0, 1).toUpperCase(),
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(scan.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              '${scan.timestamp.day}/${scan.timestamp.month}/${scan.timestamp.year} • ${isCompleted ? "Analysis Ready" : "Processing..."}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isCompleted ? statusColor : Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCompleted ? (scan.resultLabel ?? 'N/A') : 'Pending',
                    style: TextStyle(
                      color: isCompleted ? statusColor : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
              ],
            ),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(scan: scan))),
          ),
        );
      }).toList(),
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
}

// Simple Settings Placeholder Screen
class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSettingsSection('Account', [
            _buildSettingsTile(Icons.person_outline, 'Profile', 'Dr. Ahmed Atif'),
            _buildSettingsTile(Icons.badge_outlined, 'Credentials', 'Ophthalmologist'),
          ]),
          const SizedBox(height: 20),
          _buildSettingsSection('Application', [
            _buildSettingsTile(Icons.language_outlined, 'Language', 'English'),
            _buildSettingsTile(Icons.notifications_outlined, 'Notifications', 'Enabled'),
            _buildSettingsTile(Icons.dark_mode_outlined, 'Theme', 'Light'),
          ]),
          const SizedBox(height: 20),
          _buildSettingsSection('AI Model', [
            _buildSettingsTile(Icons.psychology_outlined, 'Model Version', 'DR-ResNet-v2.3.1'),
            _buildSettingsTile(Icons.tune_rounded, 'Confidence Threshold', '70%'),
          ]),
          const SizedBox(height: 20),
          _buildSettingsSection('About', [
            _buildSettingsTile(Icons.info_outline, 'App Version', '1.0.0'),
            _buildSettingsTile(Icons.privacy_tip_outlined, 'Privacy Policy', ''),
          ]),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary, fontSize: 13)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppTheme.primaryBlue, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: subtitle.isNotEmpty
          ? Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))
          : const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
      onTap: () {},
    );
  }
}
