import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/services/firebase_service.dart';
import '../../models/scan_record.dart';
import '../../models/patient.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedFilter = 'Today'; // Default is Today, 'All Time' removed
  
  // Cache the streams so they don't recreate on rebuild, preventing connection spinner flickering
  late final Stream<List<ScanRecord>> _scansStream;
  late final Stream<List<Patient>> _patientsStream;

  @override
  void initState() {
    super.initState();
    _scansStream = FirebaseService().getAllScans();
    _patientsStream = FirebaseService().getPatients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Analytics & Reports',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<ScanRecord>>(
        stream: _scansStream,
        builder: (context, scansSnapshot) {
          // Only show spinner on initial load
          if (scansSnapshot.connectionState == ConnectionState.waiting && !scansSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            );
          }

          final scans = scansSnapshot.data ?? [];
          final completedScans = scans.where((s) => s.status == ScanStatus.completed).toList();

          // Apply date filter
          final DateTime now = DateTime.now();
          final DateTime today = DateTime(now.year, now.month, now.day);
          
          final filteredScans = completedScans.where((scan) {
            if (_selectedFilter == 'Today') {
              return scan.timestamp.isAfter(today);
            } else if (_selectedFilter == 'This Week') {
              // Saturday to Friday week calculation
              int daysToSubtract;
              if (now.weekday == DateTime.saturday) {
                daysToSubtract = 0;
              } else if (now.weekday == DateTime.sunday) {
                daysToSubtract = 1;
              } else {
                daysToSubtract = now.weekday + 1; // weekday (1 for Monday) + 1 = 2 days to subtract to Saturday
              }
              final startOfWeek = today.subtract(Duration(days: daysToSubtract));
              return scan.timestamp.isAfter(startOfWeek);
            } else if (_selectedFilter == 'This Month') {
              final startOfMonth = DateTime(now.year, now.month, 1);
              return scan.timestamp.isAfter(startOfMonth);
            } else if (_selectedFilter == 'Last Month') {
              final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
              final endOfLastMonth = DateTime(now.year, now.month, 1);
              return scan.timestamp.isAfter(startOfLastMonth) && scan.timestamp.isBefore(endOfLastMonth);
            }
            return true;
          }).toList();

          // 1. Calculate DR Severity counts from filtered scans
          int noDr = 0;
          int mild = 0;
          int moderate = 0;
          int severe = 0;
          int proliferative = 0;

          for (var scan in filteredScans) {
            switch (scan.resultLabel) {
              case 'No DR':
                noDr++;
                break;
              case 'Mild':
                mild++;
                break;
              case 'Moderate':
                moderate++;
                break;
              case 'Severe':
                severe++;
                break;
              case 'Proliferative':
                proliferative++;
                break;
            }
          }

          final totalScans = filteredScans.length;
          final stageCounts = [
            noDr.toDouble(),
            mild.toDouble(),
            moderate.toDouble(),
            severe.toDouble(),
            proliferative.toDouble()
          ];
          final stageLabels = ['No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative'];
          final stageColors = [
            AppTheme.successGreen,
            Colors.lightGreen,
            AppTheme.warningOrange,
            Colors.orange,
            AppTheme.errorRed
          ];

          return StreamBuilder<List<Patient>>(
            stream: _patientsStream,
            builder: (context, patientsSnapshot) {
              // Only show spinner on initial load
              if (patientsSnapshot.connectionState == ConnectionState.waiting && !patientsSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                );
              }

              final patients = patientsSnapshot.data ?? [];

              // Filter patients based on their registration date
              final filteredPatients = patients.where((p) {
                if (_selectedFilter == 'Today') {
                  return p.createdAt.isAfter(today);
                } else if (_selectedFilter == 'This Week') {
                  int daysToSubtract;
                  if (now.weekday == DateTime.saturday) {
                    daysToSubtract = 0;
                  } else if (now.weekday == DateTime.sunday) {
                    daysToSubtract = 1;
                  } else {
                    daysToSubtract = now.weekday + 1;
                  }
                  final startOfWeek = today.subtract(Duration(days: daysToSubtract));
                  return p.createdAt.isAfter(startOfWeek);
                } else if (_selectedFilter == 'This Month') {
                  final startOfMonth = DateTime(now.year, now.month, 1);
                  return p.createdAt.isAfter(startOfMonth);
                } else if (_selectedFilter == 'Last Month') {
                  final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
                  final endOfLastMonth = DateTime(now.year, now.month, 1);
                  return p.createdAt.isAfter(startOfLastMonth) && p.createdAt.isBefore(endOfLastMonth);
                }
                return true;
              }).toList();

              // 2. Gender and age distribution counts
              int maleCount = 0;
              int femaleCount = 0;
              double avgAge = 0;
              int ageSum = 0;
              int patientsWithAge = 0;

              for (var p in filteredPatients) {
                if (p.gender?.toLowerCase() == 'male') maleCount++;
                if (p.gender?.toLowerCase() == 'female') femaleCount++;
                if (p.age != null) {
                  ageSum += p.age!;
                  patientsWithAge++;
                }
              }

              final totalGenderCount = maleCount + femaleCount;
              final double malePercent = totalGenderCount == 0 ? 0.0 : (maleCount / totalGenderCount);
              final double femalePercent = totalGenderCount == 0 ? 0.0 : (femaleCount / totalGenderCount);
              avgAge = patientsWithAge == 0 ? 0.0 : (ageSum / patientsWithAge);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Filter Bar
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: _buildFilterSelector(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // DR Severity Chart Card
                          _buildSectionCard(
                            title: 'DR Severity Distribution',
                            subtitle: 'Overview of retinopathy classification stages',
                            child: Column(
                              children: [
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CustomPaint(
                                          size: const Size(140, 140),
                                          painter: DonutChartPainter(
                                            values: stageCounts,
                                            colors: stageColors,
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$totalScans',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textDark,
                                              ),
                                            ),
                                            const Text(
                                              'Scans Done',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: AppTheme.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: List.generate(stageLabels.length, (index) {
                                          final count = stageCounts[index].toInt();
                                          final double percent = totalScans == 0 ? 0.0 : (count / totalScans) * 100;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 3),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: stageColors[index],
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    stageLabels[index],
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppTheme.textDark,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${percent.toStringAsFixed(0)}% ($count)',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Demographics Card
                          _buildSectionCard(
                            title: 'Patient Demographics',
                            subtitle: 'Gender and average age diagnostics',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.male_rounded, color: Colors.blue, size: 16),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Male',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      color: AppTheme.textDark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                '${(malePercent * 100).toStringAsFixed(0)}% ($maleCount)',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              value: malePercent,
                                              minHeight: 6,
                                              backgroundColor: Colors.grey.shade100,
                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.female_rounded, color: Colors.pink, size: 16),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Female',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      color: AppTheme.textDark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                '${(femalePercent * 100).toStringAsFixed(0)}% ($femaleCount)',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              value: femalePercent,
                                              minHeight: 6,
                                              backgroundColor: Colors.grey.shade100,
                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.pink),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Average Patient Age',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    Text(
                                      '${avgAge.toStringAsFixed(1)} Years',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterSelector() {
    final filters = ['Today', 'This Week', 'This Month', 'Last Month'];
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.primaryBlue,
              backgroundColor: Colors.white,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFilter = filter);
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade200,
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          child,
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0, (sum, val) => sum + val);
    if (total == 0) {
      final paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2 - 8,
        paint,
      );
      return;
    }

    double startAngle = -pi / 2;
    final double radius = size.width / 2 - 8;
    final Offset center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final double sweepAngle = (values[i] / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + 0.05,
        sweepAngle - 0.1,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
