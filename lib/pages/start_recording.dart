import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hemoglobin_predictor/pages/result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class StartRecording extends StatefulWidget {
  const StartRecording({super.key});

  @override
  State<StartRecording> createState() => _StartRecordingState();
}

class _StartRecordingState extends State<StartRecording> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isFlashOn = true;
  XFile? _videoFile;
  bool _isUploading = false;
  String? _errorMessage;

  // Timer variables
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  static const int _maxRecordingDuration = 10; // 15 seconds

  // Focus animation
  Offset? _focusPoint;
  bool _showFocusCircle = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      print('🎥 Starting camera initialization...');

      // Request camera permission
      print('📱 Requesting camera permission...');
      final status = await Permission.camera.request();
      print('✅ Camera permission status: $status');

      if (status.isDenied) {
        setState(() {
          _errorMessage =
              'Camera permission denied. Please grant camera access.';
        });
        return;
      }

      if (status.isPermanentlyDenied) {
        setState(() {
          _errorMessage =
              'Camera permission permanently denied. Please enable it in Settings.';
        });
        _showPermissionSettingsDialog();
        return;
      }

      print('📷 Getting available cameras...');
      final cameras = await availableCameras();
      print('✅ Found ${cameras.length} cameras');

      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found on this device';
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      print('🎯 Selected camera: ${backCamera.name}');

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      print('⚙️ Initializing camera controller...');
      await _cameraController!.initialize();
      print('✅ Camera initialized successfully');

      // Set focus mode to auto
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
        print('✅ Focus mode set to auto');
      } catch (e) {
        print('⚠️ Could not set focus mode: $e');
      }

      // Check if flash is available
      final hasFlash = _cameraController!.value.flashMode != null;
      print('💡 Flash available: $hasFlash');

      if (hasFlash) {
        await _cameraController!.setFlashMode(FlashMode.torch);
        print('✅ Flash mode set to torch');
      } else {
        print('⚠️ Flash not available on this device');
        setState(() {
          _isFlashOn = false;
        });
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
        print('✅ Camera ready to use');
      }
    } catch (e, stackTrace) {
      print('❌ Error initializing camera: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: ${e.toString()}';
          _isInitialized = false;
        });
      }
    }
  }

  Future<void> _onCameraTap(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final offset = Offset(
        details.localPosition.dx / constraints.maxWidth,
        details.localPosition.dy / constraints.maxHeight,
      );

      await _cameraController!.setFocusPoint(offset);
      await _cameraController!.setExposurePoint(offset);

      setState(() {
        _focusPoint = details.localPosition;
        _showFocusCircle = true;
      });

      // Hide focus circle after 2 seconds
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showFocusCircle = false;
          });
        }
      });

      print('🎯 Focus set to: ${offset.dx}, ${offset.dy}');
    } catch (e) {
      print('❌ Error setting focus: $e');
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.settings, color: Color(0xFFD64545), size: 28),
            SizedBox(width: 8),
            Text('Permission Required'),
          ],
        ),
        content: Text(
          'Camera permission is permanently denied. Please enable it in Settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: Text(
              'Open Settings',
              style: TextStyle(color: Color(0xFFD64545)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFlash() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
        await _cameraController!.setFlashMode(
          _isFlashOn ? FlashMode.torch : FlashMode.off,
        );
        print('💡 Flash toggled: $_isFlashOn');
      } catch (e) {
        print('❌ Error toggling flash: $e');
      }
    }
  }

  void _startTimer() {
    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;
      });

      if (_recordingSeconds >= _maxRecordingDuration) {
        _stopRecording();
      }
    });
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    if (_cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_isRecording) {
      try {
        print('🎬 Starting video recording...');
        await _cameraController!.startVideoRecording();
        setState(() {
          _isRecording = true;
        });
        print('✅ Recording started');
        _startTimer();
      } catch (e) {
        print('❌ Error starting recording: $e');
        _showErrorDialog('Failed to start recording: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController != null && _isRecording) {
      try {
        print('⏹️ Stopping video recording...');
        _stopTimer();

        _videoFile = await _cameraController!.stopVideoRecording();
        print('✅ Recording stopped. File: ${_videoFile!.path}');

        setState(() {
          _isRecording = false;
        });

        await _cameraController!.setFlashMode(FlashMode.off);
        await _cameraController?.dispose();
        _cameraController = null;

        await _sendVideoToBackend(_videoFile!.path);
      } catch (e) {
        print('❌ Error stopping recording: $e');
        _showErrorDialog('Failed to stop recording: $e');
      }
    }
  }

  Map<String, dynamic> generateHbStatus() {
    final random = Random();

    // Generate Hb with weighted probability towards normal range (12-16 g/dL)
    // 70% normal, 20% low, 10% high
    double hb;
    final probability = random.nextDouble();

    if (probability < 0.70) {
      // 70% chance: Normal range (12.0 - 16.5 g/dL)
      hb = 12.0 + random.nextDouble() * 4.5;
    } else if (probability < 0.90) {
      // 20% chance: Low range (8.0 - 11.9 g/dL)
      hb = 8.0 + random.nextDouble() * 3.9;
    } else {
      // 10% chance: High range (16.6 - 20.0 g/dL)
      hb = 16.6 + random.nextDouble() * 3.4;
    }

    hb = double.parse(hb.toStringAsFixed(1));

    String status;
    String message;
    String recommendation;

    if (hb < 12.0) {
      status = 'Low';

      if (hb < 8.5) {
        // Severely low
        message =
            'Your hemoglobin level is significantly below normal. This indicates severe anemia, which can cause extreme fatigue, shortness of breath, dizziness, and pale skin.';
        recommendation =
            '⚠️ Immediate Action Required:\n'
            '• Consult a doctor immediately for proper diagnosis\n'
            '• You may need iron supplements or medical treatment\n'
            '• Eat iron-rich foods: red meat, liver, spinach, lentils\n'
            '• Include vitamin C to boost iron absorption (citrus fruits)\n'
            '• Avoid tea/coffee with meals as they reduce iron absorption';
      } else if (hb < 10.0) {
        // Moderately low
        message =
            'Your hemoglobin level is moderately low. This can cause fatigue, weakness, headaches, and difficulty concentrating. You may experience shortness of breath during physical activity.';
        recommendation =
            '⚠️ Medical Attention Recommended:\n'
            '• Schedule an appointment with your doctor\n'
            '• Increase iron intake: eggs, fish, dried fruits, beans\n'
            '• Add folate-rich foods: broccoli, peas, fortified cereals\n'
            '• Consider vitamin B12: dairy, eggs, fortified foods\n'
            '• Get adequate rest and avoid strenuous activities';
      } else {
        // Mildly low
        message =
            'Your hemoglobin level is slightly below normal. You might feel occasional tiredness or weakness, especially after physical exertion.';
        recommendation =
            '💡 Dietary Improvements Suggested:\n'
            '• Increase iron-rich foods: lean meat, tofu, pumpkin seeds\n'
            '• Pair iron sources with vitamin C (oranges, tomatoes)\n'
            '• Include dark leafy greens: kale, spinach, Swiss chard\n'
            '• Add whole grains and legumes to your diet\n'
            '• Monitor your levels and consult a doctor if symptoms persist';
      }
    } else if (hb >= 12.0 && hb <= 16.5) {
      status = 'Normal';

      if (hb >= 12.0 && hb < 13.5) {
        message =
            'Your hemoglobin level is in the healthy range, towards the lower end of normal. This is generally fine, but maintaining good nutrition is important.';
        recommendation =
            '✅ Maintain Healthy Habits:\n'
            '• Continue eating a balanced diet with adequate iron\n'
            '• Include protein sources: chicken, fish, legumes, nuts\n'
            '• Stay hydrated and get regular exercise\n'
            '• Ensure sufficient sleep (7-9 hours daily)\n'
            '• Regular health checkups to monitor your levels';
      } else if (hb >= 13.5 && hb <= 15.0) {
        message =
            'Excellent! Your hemoglobin level is in the optimal healthy range. You should have good energy levels and normal oxygen delivery throughout your body.';
        recommendation =
            '✅ Keep Up the Good Work:\n'
            '• Maintain your current healthy lifestyle\n'
            '• Continue balanced diet with iron, B12, and folate\n'
            '• Stay physically active with regular exercise\n'
            '• Adequate hydration (8-10 glasses of water daily)\n'
            '• Annual health checkups for preventive care';
      } else {
        message =
            'Your hemoglobin level is in the healthy range, towards the upper end of normal. This is typically a sign of good health and fitness.';
        recommendation =
            '✅ Excellent Health Status:\n'
            '• Continue your healthy eating habits\n'
            '• Stay active and maintain fitness routine\n'
            '• Ensure proper hydration throughout the day\n'
            '• Balance iron intake - no need for supplements\n'
            '• Regular monitoring during annual checkups';
      }
    } else {
      status = 'High';

      if (hb > 18.0) {
        message =
            'Your hemoglobin level is significantly above normal. This condition (polycythemia) can increase blood thickness, potentially leading to blood clots, headaches, and dizziness.';
        recommendation =
            '⚠️ Medical Consultation Required:\n'
            '• See a doctor as soon as possible for evaluation\n'
            '• This may require medical investigation and treatment\n'
            '• Stay well-hydrated to prevent blood thickening\n'
            '• Avoid smoking and excessive alcohol consumption\n'
            '• Do not take iron supplements without medical advice';
      } else if (hb > 17.0) {
        message =
            'Your hemoglobin level is moderately elevated. This could be due to dehydration, smoking, living at high altitude, or an underlying condition requiring medical attention.';
        recommendation =
            '⚠️ Recommended Actions:\n'
            '• Consult your doctor for proper evaluation\n'
            '• Increase water intake significantly (10-12 glasses daily)\n'
            '• Avoid iron supplements unless prescribed\n'
            '• Monitor for symptoms: headaches, fatigue, blurred vision\n'
            '• If you smoke, consider quitting programs';
      } else {
        message =
            'Your hemoglobin level is slightly elevated. This is often temporary and can be caused by dehydration, but it\'s worth monitoring.';
        recommendation =
            '💡 Lifestyle Adjustments:\n'
            '• Increase fluid intake throughout the day\n'
            '• Avoid excessive caffeine and alcohol\n'
            '• Recheck levels after 1-2 weeks of good hydration\n'
            '• Consult a doctor if levels remain elevated\n'
            '• Do not take iron or other supplements without advice';
      }
    }

    return {
      'hb': hb,
      'status': status,
      'message': message,
      'recommendation': recommendation,
    };
  }

  Future<void> _saveScanResultToHistory({
    required double hb,
    required String status,
    required String message,
    required String recommendation,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Existing history list
    final List<String> rawHistory = prefs.getStringList('scanHistory') ?? [];

    // Create a new record (stored as JSON string)
    final newRecord = {
      'hb': hb,
      'status': status,
      'message': message,
      'recommendation': recommendation,
      'date': DateTime.now().toIso8601String(),
    };

    rawHistory.insert(0, newRecord.toString()); // Add newest first
    await prefs.setStringList('scanHistory', rawHistory);

    // Also store "last scan" info for home screen
    await prefs.setDouble('lastHb', hb);
    await prefs.setString('lastStatus', status);
    await prefs.setString('lastDate', newRecord['date']!.toString());
  }

  Future<void> _sendVideoToBackend(String videoPath) async {
    setState(() {
      _isUploading = true;
      _isInitialized = false;
    });

    try {
      print('📤 Uploading video from: $videoPath');
      await Future.delayed(Duration(seconds: 4));

      final mockHbData = generateHbStatus();
      final prefs = await SharedPreferences.getInstance();

      Map<String, dynamic> mockResponse = {
        'success': true,
        'hemoglobin_level': mockHbData['hb'].toString(),
        'status': mockHbData['status'],
        'message': mockHbData['message'],
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _saveScanResultToHistory(
        hb: mockHbData['hb'],
        status: mockHbData['status'],
        message: mockHbData['message'],
        recommendation: mockHbData['recommendation'],
      );

      setState(() {
        _isUploading = false;
      });

      print('✅ Upload complete');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HemoglobinResultScreen(
              hemoglobinLevel: mockResponse['hemoglobin_level'],
              status: mockResponse['status'],
              message: mockResponse['message'],
              recommendation: mockHbData['recommendation'],
              age: prefs.getString('age') ?? '',
              weight: prefs.getString('weight') ?? '',
              skinColor: prefs.getString('skinColor') ?? '',

            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      print('❌ Error uploading video: $e');
      _showErrorDialog('Error uploading video: $e');
    }
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('OK', style: TextStyle(color: Color(0xFFD64545))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    print('🧹 Disposing camera resources...');
    _stopTimer();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isRecording) {
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (!_isUploading)
              SafeArea(
                child: Column(
                  children: [
                    // Top bar - Compact design
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.arrow_back,
                              size: 28,
                              color: Colors.white,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                          SizedBox(width: 48),
                          IconButton(
                            onPressed: _toggleFlash,
                            icon: Icon(
                              _isFlashOn ? Icons.flash_on : Icons.flash_off,
                              size: 28,
                              color: (_isFlashOn ? Colors.amber : Colors.white),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 48),
                    // Instructions - Compact
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8,
                      ),
                      child: Text(
                        'Place fingertip on camera lens. Tap to focus.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ),

                    // Camera preview - Maximum size
                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: _buildCameraPreview(),
                      ),
                    ),

                    // Bottom controls - Compact
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          // Recording status text
                          if (_isRecording)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                'Time remaining: ${_formatTime(_maxRecordingDuration - _recordingSeconds)}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          // Start/Stop button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed:
                                  (_isRecording ||
                                      !_isInitialized ||
                                      _errorMessage != null)
                                  ? null
                                  : _startRecording,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFD64545),
                                disabledBackgroundColor: Colors.grey[800],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _isRecording
                                    ? 'Recording...'
                                    : 'Start Recording',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Uploading overlay
            if (_isUploading)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          color: Color(0xFFD64545),
                          strokeWidth: 6,
                        ),
                      ),
                      SizedBox(height: 32),
                      Text(
                        'Analyzing Video...',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Please wait while we process\nyour hemoglobin reading',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Color(0xFFD64545),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.transparent,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'This may take up to 30 seconds',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.access_time,
                              color: Color(0xFFD64545),
                              size: 20,
                            ),
                          ],
                        ),
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

  Widget _buildCameraPreview() {
    if (_errorMessage != null) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Color(0xFFD64545)),
                SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                    });
                    _initializeCamera();
                  },
                  icon: Icon(Icons.refresh),
                  label: Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFD64545),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFD64545)),
              SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) => _onCameraTap(details, constraints),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full-size camera preview
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),

              // Focus circle overlay
              if (_isInitialized && _errorMessage == null)
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFFD64545), width: 3),
                    ),
                  ),
                ),

              // Tap-to-focus indicator
              if (_showFocusCircle && _focusPoint != null)
                Positioned(
                  left: _focusPoint!.dx - 40,
                  top: _focusPoint!.dy - 40,
                  child: TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 300),
                    tween: Tween(begin: 1.5, end: 1.0),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.center_focus_strong,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
