import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/patient.dart';
import '../../models/scan_record.dart';
import '../patients/patient_list_screen.dart';
import 'custom_camera_screen.dart';
import 'result_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/local_database.dart';
import '../../core/services/rpi_service.dart';
import '../../core/services/pdf_report_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with TickerProviderStateMixin {
  File? _leftImage;
  File? _rightImage;
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

  Future<void> _pickImage(bool isLeft) async {
    final File? result = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomCameraScreen(
          eyeName: isLeft ? 'Left Eye (OS)' : 'Right Eye (OD)',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isLeft) {
          _leftImage = result;
        } else {
          _rightImage = result;
        }
      });
    }
  }

  Future<void> _pickFromGallery(bool isLeft) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (isLeft) {
          _leftImage = File(pickedFile.path);
        } else {
          _rightImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _showIpSettingsDialog() async {
    final rpiService = RpiService();
    final currentIp = await rpiService.getIpAddress();
    final controller = TextEditingController(text: currentIp);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Raspberry Pi IP Settings'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'IP Address',
              hintText: 'e.g., 10.42.0.1',
            ),
            keyboardType: TextInputType.text,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await rpiService.setIpAddress(controller.text);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('IP updated to ${controller.text}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _analyzeAndShowResults() async {
    if (_leftImage == null || _rightImage == null || _selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please capture both images (OS and OD) and select a patient'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      // 1. Verify if the Raspberry Pi server is reachable
      final rpiService = RpiService();
      final isAvailable = await rpiService.isAvailable();
      
      if (!isAvailable) {
        setState(() => _isAnalyzing = false);
        if (mounted) {
          final currentIp = await rpiService.getIpAddress();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot reach Raspberry Pi at $currentIp.'),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: _showIpSettingsDialog,
              ),
              duration: const Duration(seconds: 8),
            ),
          );
        }
        return;
      }

      // 2. Upload both images and get predictions from local Pi server
      final result = await rpiService.analyzeDualImages(
        leftEye: _leftImage!,
        rightEye: _rightImage!,
      );
      
      print('DEBUG: analyzeDualImages result = $result');
      
      Map<String, dynamic> parseEyeResult(dynamic eyeData) {
        if (eyeData is Map) {
          return Map<String, dynamic>.from(eyeData);
        } else if (eyeData is String) {
          final label = eyeData.trim().toLowerCase();
          int stage = 0;
          String resultLabel = 'No DR';
          
          if (label.contains('proliferative')) {
            stage = 4;
            resultLabel = 'Proliferative';
          } else if (label.contains('severe')) {
            stage = 3;
            resultLabel = 'Severe';
          } else if (label.contains('moderate')) {
            stage = 2;
            resultLabel = 'Moderate';
          } else if (label.contains('mild')) {
            stage = 1;
            resultLabel = 'Mild';
          } else if (label.contains('ok') || label.contains('no dr') || label.contains('healthy') || label.contains('normal')) {
            stage = 0;
            resultLabel = 'No DR';
          } else {
            // Default/Fallback
            resultLabel = eyeData;
            stage = 0;
          }
          
          return {
            'stage': stage,
            'resultLabel': resultLabel,
            'confidence': 100.0,
          };
        } else {
          throw FormatException('Unexpected eye data type: ${eyeData?.runtimeType}');
        }
      }

      Map<String, dynamic> leftResult;
      Map<String, dynamic> rightResult;
      try {
        leftResult = parseEyeResult(result['left']);
        rightResult = parseEyeResult(result['right']);
      } catch (castError) {
        print('ERROR: Parsing failed on result maps. Result was: $result, Error: $castError');
        throw FormatException(
          'Pi returned unexpected format: '
          'left is ${result['left']?.runtimeType}, '
          'right is ${result['right']?.runtimeType}. '
          'Raw: $result. Details: $castError'
        );
      }
      
      final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'offline_user_123';
      final String scanId = DateTime.now().millisecondsSinceEpoch.toString();

      // 3. Create ScanRecord locally (leftImageUrl and rightImageUrl store local file paths)
      final scan = ScanRecord(
        id: scanId,
        userId: currentUid,
        patientId: _selectedPatient!.id,
        patientName: _selectedPatient!.name,
        status: ScanStatus.completed,
        timestamp: DateTime.now(),
        leftImageUrl: _leftImage!.path,
        leftStage: leftResult['stage'] as int?,
        leftResultLabel: leftResult['resultLabel'] as String?,
        leftConfidence: (leftResult['confidence'] as num?)?.toDouble(),
        rightImageUrl: _rightImage!.path,
        rightStage: rightResult['stage'] as int?,
        rightResultLabel: rightResult['resultLabel'] as String?,
        rightConfidence: (rightResult['confidence'] as num?)?.toDouble(),
      );

      // 4. Save to local DB (Hive)
      await LocalDatabase().saveScan(scan);

      // [AUTO] Background PDF generation - fire and forget, non-blocking
      PdfReportService().saveReportLocally(scan).then((file) {
        if (file != null) {
          print('DEBUG: PDF report auto-saved to ${file.path}');
        }
      });

      // 5. Update patient's last scan date locally
      final updatedPatient = Patient(
        id: _selectedPatient!.id,
        name: _selectedPatient!.name,
        createdAt: _selectedPatient!.createdAt,
        lastScanDate: scan.timestamp,
        phone: _selectedPatient!.phone,
        age: _selectedPatient!.age,
        gender: _selectedPatient!.gender,
      );
      await LocalDatabase().savePatient(updatedPatient);

      // 6. Queue the scan for background synchronization
      await LocalDatabase().addToPendingSync(scan.id, 'scan');

      if (mounted) {
        // Navigate to result screen with local scan record
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(scan: scan),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
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
    return Row(
      children: [
        // Left Eye (OS)
        Expanded(
          child: _buildSingleViewfinder(
            title: 'Left Eye (OS)',
            image: _leftImage,
            onCapture: () => _pickImage(true),
            onGallery: () => _pickFromGallery(true),
            onClear: () => setState(() => _leftImage = null),
          ),
        ),
        const SizedBox(width: 16),
        // Right Eye (OD)
        Expanded(
          child: _buildSingleViewfinder(
            title: 'Right Eye (OD)',
            image: _rightImage,
            onCapture: () => _pickImage(false),
            onGallery: () => _pickFromGallery(false),
            onClear: () => setState(() => _rightImage = null),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleViewfinder({
    required String title,
    required File? image,
    required VoidCallback onCapture,
    required VoidCallback onGallery,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (image != null)
                  Image.file(
                    image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D1B2A), Color(0xFF1B2A4A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                // Corner brackets
                _buildCornerBrackets(),

                // Clear button
                if (image != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: onClear,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),

                // Actions if empty
                if (image == null)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: onCapture,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) => Transform.scale(
                            scale: _pulseAnimation.value,
                            child: child,
                          ),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryBlue.withOpacity(0.9),
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.4),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: onGallery,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_library_outlined, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Gallery',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                // Success Badge
                if (image != null)
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Ready',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
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

    Widget corner(
      double? top,
      double? bottom,
      double? left,
      double? right, {
      required bool flipH,
      required bool flipV,
    }) {
      return Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: Transform.scale(
          scaleX: flipH ? -1 : 1,
          scaleY: flipV ? -1 : 1,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _CornerPainter(color: color, thickness: thickness),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(16, null, 16, null, flipH: false, flipV: false),
        corner(16, null, null, 16, flipH: true, flipV: false),
        corner(null, 16, 16, null, flipH: false, flipV: true),
        corner(null, 16, null, 16, flipH: true, flipV: true),
      ],
    );
  }

  Widget _buildPatientSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Patient',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppTheme.textDark,
          ),
        ),
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
                color: _selectedPatient != null
                    ? AppTheme.primaryBlue.withOpacity(0.4)
                    : Colors.grey.shade200,
                width: _selectedPatient != null ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
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
                    _selectedPatient != null
                        ? Icons.person
                        : Icons.person_search_outlined,
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
                          color: _selectedPatient != null
                              ? AppTheme.textDark
                              : AppTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: _selectedPatient != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      if (_selectedPatient == null)
                        const Text(
                          'Tap to choose from patient list',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  _selectedPatient != null
                      ? Icons.check_circle
                      : Icons.keyboard_arrow_right,
                  color: _selectedPatient != null
                      ? AppTheme.successGreen
                      : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Analyze button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _analyzeAndShowResults,
              icon: const Icon(Icons.biotech_rounded, size: 20),
              label: const Text(
                'Analyze Scan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
                  child: Icon(
                    Icons.remove_red_eye_outlined,
                    size: 40,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'AI Analysis in Progress...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryBlue,
                ),
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
    canvas.drawLine(
      center - const Offset(20, 0),
      center + const Offset(20, 0),
      crossPaint,
    );
    canvas.drawLine(
      center - const Offset(0, 20),
      center + const Offset(0, 20),
      crossPaint,
    );
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
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
