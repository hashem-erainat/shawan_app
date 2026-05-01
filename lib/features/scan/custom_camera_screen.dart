import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import '../../core/theme.dart';

class CustomCameraScreen extends StatefulWidget {
  const CustomCameraScreen({super.key});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) return;

    _controller = CameraController(
      _cameras![0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      
      // Load the image
      final bytes = await image.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      
      if (originalImage != null) {
        // Handle rotation if necessary (cameras often capture in landscape)
        if (originalImage.width > originalImage.height) {
          originalImage = img.copyRotate(originalImage, angle: 90);
        }

        final screenSize = MediaQuery.of(context).size;
        final circleRadius = 120.0;
        final center = Offset(screenSize.width / 2, screenSize.height / 2 - 20);

        // Calculate scale factors
        final scaleX = originalImage.width / screenSize.width;
        final scaleY = originalImage.height / screenSize.height;
        
        // Use the larger scale to ensure we cover the area
        final scale = scaleX > scaleY ? scaleX : scaleY;

        // Calculate crop rectangle in image coordinates
        final cropSize = (circleRadius * 2 * scale).toInt();
        final cropX = (center.dx * scaleX - cropSize / 2).toInt();
        final cropY = (center.dy * scaleY - cropSize / 2).toInt();

        // Crop the image to a square containing the circle
        final croppedImage = img.copyCrop(
          originalImage,
          x: cropX.clamp(0, originalImage.width - cropSize),
          y: cropY.clamp(0, originalImage.height - cropSize),
          width: cropSize,
          height: cropSize,
        );

        // Save the cropped image back to a file
        final croppedBytes = img.encodeJpg(croppedImage);
        final directory = await Directory.systemTemp.createTemp();
        final croppedPath = '${directory.path}/cropped_eye.jpg';
        final croppedFile = File(croppedPath)..writeAsBytesSync(croppedBytes);

        if (mounted) {
          Navigator.pop(context, croppedFile);
        }
      }
    } catch (e) {
      debugPrint('Error taking/cropping picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),

          // Focus Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: EyeFocusPainter(),
            ),
          ),

          // Top Controls
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
                const Text(
                  'Focus on Eye',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 48), // Placeholder for balance
              ],
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Align the eye within the circle',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EyeFocusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final circleRadius = 120.0;
    final center = Offset(size.width / 2, size.height / 2 - 20);

    // Create a path for the background with a hole in the middle
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: circleRadius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // Draw the focus ring
    final ringPaint = Paint()
      ..color = AppTheme.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawCircle(center, circleRadius, ringPaint);

    // Draw crosshair
    final crossPaint = Paint()
      ..color = AppTheme.primaryBlue.withOpacity(0.5)
      ..strokeWidth = 1;
    
    canvas.drawLine(center - const Offset(20, 0), center + const Offset(20, 0), crossPaint);
    canvas.drawLine(center - const Offset(0, 20), center + const Offset(0, 20), crossPaint);

    // Draw corners around the circle
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    final cornerLen = 30.0;
    final offset = circleRadius + 10;
    
    // Top Left
    canvas.drawPath(Path()
      ..moveTo(center.dx - offset, center.dy - offset + cornerLen)
      ..lineTo(center.dx - offset, center.dy - offset)
      ..lineTo(center.dx - offset + cornerLen, center.dy - offset), cornerPaint);

    // Top Right
    canvas.drawPath(Path()
      ..moveTo(center.dx + offset - cornerLen, center.dy - offset)
      ..lineTo(center.dx + offset, center.dy - offset)
      ..lineTo(center.dx + offset, center.dy - offset + cornerLen), cornerPaint);

    // Bottom Left
    canvas.drawPath(Path()
      ..moveTo(center.dx - offset, center.dy + offset - cornerLen)
      ..lineTo(center.dx - offset, center.dy + offset)
      ..lineTo(center.dx - offset + cornerLen, center.dy + offset), cornerPaint);

    // Bottom Right
    canvas.drawPath(Path()
      ..moveTo(center.dx + offset - cornerLen, center.dy + offset)
      ..lineTo(center.dx + offset, center.dy + offset)
      ..lineTo(center.dx + offset, center.dy + offset - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
