import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/patient.dart';
import '../../models/scan_record.dart';
import '../patients/patient_list_screen.dart';
import 'custom_camera_screen.dart';
import 'result_screen.dart';
import '../../core/services/firebase_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with TickerProviderStateMixin {
  File? _image;
  bool _isAnalyzing = false;
  Patient? _selectedPatient;
  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final File? result = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (context) => const CustomCameraScreen()),
    );
    
    if (result != null) {
      setState(() {
        _image = result;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _analyzeAndShowResults() async {
    if (_image == null || _selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please capture an image and select a patient'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      // Save to Firebase history and get the record
      final ScanRecord savedScan = await FirebaseService().uploadScan(
        _image!, 
        _selectedPatient!.id, 
        _selectedPatient!.name
      );

      if (mounted) {
        // Navigate to result screen with real data from Firebase
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ResultScreen(scan: savedScan)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during analysis: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  ScanRecord _generateMockScanResult(Patient patient) {
    final random = Random();
    final stages = [
      {'label': 'No DR', 'stage': 0},
      {'label': 'Mild', 'stage': 1},
      {'label': 'Moderate', 'stage': 2},
      {'label': 'Severe', 'stage': 3},
      {'label': 'Proliferative', 'stage': 4},
    ];

    // Weighted random: more likely to be No DR or Mild
    final weights = [40, 25, 20, 10, 5];
    int total = 0;
    for (var w in weights) total += w;
    int rand = random.nextInt(total);
    int selectedIndex = 0;
    int cumulative = 0;
    for (int i = 0; i < weights.length; i++) {
      cumulative += weights[i];
      if (rand < cumulative) {
        selectedIndex = i;
        break;
      }
    }

    final selected = stages[selectedIndex];

    return ScanRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'mock_user_ahmed_atif',
      patientId: patient.id,
      patientName: patient.name,
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/Fundus_photograph_of_normal_right_eye.jpg/800px-Fundus_photograph_of_normal_right_eye.jpg',
      status: ScanStatus.completed,
      stage: selected['stage'] as int,
      resultLabel: selected['label'] as String,
      timestamp: DateTime.now(),
      confidence: (75 + random.nextInt(24)).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('New Retinal Scan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            child: Column(
              children: [
                // Camera Viewfinder
                _buildCameraViewfinder(),
                const SizedBox(height: 24),

                // Patient Selector
                _buildPatientSelector(),
                const SizedBox(height: 20),

                // Tips Card
                _buildTipsCard(),
                const SizedBox(height: 100),
              ],
            ),
          ),

          // Bottom Action Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActions(),
          ),

          // Analyzing Overlay
          if (_isAnalyzing) _buildAnalyzingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraViewfinder() {
    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Image or placeholder
            if (_image != null)
              Image.file(_image!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF0D1B2A), const Color(0xFF1B2A4A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

            // Scanning overlay
            _buildScanningOverlay(),

            // Corner brackets
            _buildCornerBrackets(),

            // Retake button
            if (_image != null)
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => setState(() => _image = null),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Retake', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),

            // Tap to capture button (when no image)
            if (_image == null)
              Positioned(
                bottom: 28,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    ),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryBlue.withOpacity(0.9),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withOpacity(0.6),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ),

            // "Image captured" badge
            if (_image != null)
              Positioned(
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Image Captured', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return CustomPaint(
      size: const Size(double.infinity, 320),
      painter: _ScanCirclePainter(),
    );
  }

  Widget _buildCornerBrackets() {
    const color = Colors.white;
    const size = 20.0;
    const thickness = 2.5;

    Widget corner(double? top, double? bottom, double? left, double? right,
        {required bool flipH, required bool flipV}) {
      return Positioned(
        top: top, bottom: bottom, left: left, right: right,
        child: Transform.scale(
          scaleX: flipH ? -1 : 1,
          scaleY: flipV ? -1 : 1,
          child: SizedBox(
            width: size, height: size,
            child: CustomPaint(painter: _CornerPainter(color: color, thickness: thickness)),
          ),
        ),
      );
    }

    return Stack(children: [
      corner(16, null, 16, null, flipH: false, flipV: false),
      corner(16, null, null, 16, flipH: true, flipV: false),
      corner(null, 16, 16, null, flipH: false, flipV: true),
      corner(null, 16, null, 16, flipH: true, flipV: true),
    ]);
  }

  Widget _buildPatientSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Patient', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PatientListScreen(
                  onSelected: (patient) {
                    setState(() => _selectedPatient = patient);
                  },
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedPatient != null ? AppTheme.primaryBlue.withOpacity(0.4) : Colors.grey.shade200,
                width: _selectedPatient != null ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedPatient != null ? Icons.person : Icons.person_search_outlined,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPatient?.name ?? 'Select Patient',
                        style: TextStyle(
                          color: _selectedPatient != null ? AppTheme.textDark : AppTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: _selectedPatient != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (_selectedPatient == null)
                        const Text('Tap to choose from patient list', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(
                  _selectedPatient != null ? Icons.check_circle : Icons.keyboard_arrow_right,
                  color: _selectedPatient != null ? AppTheme.successGreen : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: AppTheme.primaryBlue, size: 18),
              const SizedBox(width: 8),
              const Text('Capture Tips', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
            ],
          ),
          const SizedBox(height: 10),
          _tip('Ensure proper alignment with the retinal camera'),
          _tip('Patient should look directly at the fixation light'),
          _tip('Avoid blinking during capture for best results'),
        ],
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          // Analyze button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _analyzeAndShowResults,
              icon: const Icon(Icons.biotech_rounded, size: 20),
              label: const Text('Analyze Scan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated scanning indicator
            SizedBox(
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => CustomPaint(
                  painter: _RadarPainter(progress: _scanLineAnimation.value),
                  child: child,
                ),
                child: const Center(
                  child: Icon(Icons.remove_red_eye_outlined, size: 40, color: AppTheme.primaryBlue),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'AI Analysis in Progress...',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Detecting diabetic retinopathy patterns',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painters
class _ScanCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 90, paint);
    canvas.drawCircle(center, 60, paint..color = Colors.white.withOpacity(0.1));

    // Crosshair
    final crossPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;
    canvas.drawLine(center - const Offset(20, 0), center + const Offset(20, 0), crossPaint);
    canvas.drawLine(center - const Offset(0, 20), center + const Offset(0, 20), crossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  const _CornerPainter({required this.color, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RadarPainter extends CustomPainter {
  final double progress;
  const _RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final circlePaint = Paint()
      ..color = AppTheme.primaryBlue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, circlePaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 3.14 * 2 * progress,
        colors: [AppTheme.primaryBlue.withOpacity(0), AppTheme.primaryBlue],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14 / 2,
      3.14 * 2 * progress,
      true,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.progress != progress;
}
