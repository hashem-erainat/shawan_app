import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RpiService {
  static final RpiService _instance = RpiService._internal();
  factory RpiService() => _instance;
  RpiService._internal();

  static const String _defaultIp = '10.42.0.1';
  static const int _port = 8000;
  static const String _prefIpKey = 'rpi_ip_address';

  Future<String> getIpAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefIpKey) ?? _defaultIp;
  }

  Future<void> setIpAddress(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefIpKey, ip.trim());
  }

  Future<String> getBaseUrl() async {
    final ip = await getIpAddress();
    return 'http://$ip:$_port';
  }

  /// Pings the Raspberry Pi server to check if it's available.
  Future<bool> isAvailable() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'online';
      }
      return false;
    } catch (e) {
      print('DEBUG: Raspberry Pi is unavailable: $e');
      return false;
    }
  }

  /// Sends the eye image file to the Raspberry Pi FastAPI server for analysis.
  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/predict');
      
      final request = http.MultipartRequest('POST', uri);
      
      // Attach the image file
      final multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      );
      request.files.add(multipartFile);
      
      print('DEBUG: Sending image to Pi at $uri');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('DEBUG: Received prediction from Pi: $data');
        return data;
      } else {
        throw HttpException('Pi server returned status code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('ERROR: Failed to analyze image on Pi: $e');
      rethrow;
    }
  }

  /// Sends both eye image files to the Raspberry Pi FastAPI server for analysis in a single request.
  Future<Map<String, dynamic>> analyzeDualImages({
    required File leftEye,
    required File rightEye,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/predict_dual');
      
      final request = http.MultipartRequest('POST', uri);
      
      // Attach both images
      final leftMultipart = await http.MultipartFile.fromPath('left_eye', leftEye.path);
      final rightMultipart = await http.MultipartFile.fromPath('right_eye', rightEye.path);
      
      request.files.add(leftMultipart);
      request.files.add(rightMultipart);
      
      print('DEBUG: Sending dual eye images to Pi at $uri');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);
      
      print('DEBUG: Pi response status: ${response.statusCode}');
      print('DEBUG: Pi raw response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        } else {
          throw FormatException('Response is not a JSON Map. Decoded type: ${decoded.runtimeType}');
        }
      } else {
        throw HttpException('Pi server returned status code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('ERROR: Failed to analyze dual images on Pi: $e');
      rethrow;
    }
  }
}
