import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hemoglobin_predictor/pages/result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io'; // ✅ for video size

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_compress/video_compress.dart'; // ✅ for compression

// ✅ Processing phases for nicer UI messages
enum _ProcessingStage { none, compressing, uploading }

class StartRecording extends StatefulWidget {
  const StartRecording({super.key});

  @override
  State<StartRecording> createState() => _StartRecordingState();
}

class _StartRecordingState extends State<StartRecording>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isFlashOn = true;
  XFile? _videoFile;
  String? _errorMessage;

  // Timer variables
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  static const int _maxRecordingDuration = 15; // ✅ 15 seconds

  // Focus animation
  Offset? _focusPoint;
  bool _showFocusCircle = false;

  // ✅ Guard to avoid double stop
  bool _isStoppingRecording = false;

  // ✅ PPG-safe targets: try for ~5 MB, allow up to ~8 MB if needed
  static const int _softMaxFileSizeBytes = 5 * 1024 * 1024;
  static const int _hardMaxFileSizeBytes = 8 * 1024 * 1024;

  // ✅ Processing state (for compressing vs uploading UI)
  _ProcessingStage _processingStage = _ProcessingStage.none;

  // ✅ Single source of truth: is the camera really ready?
  bool get _isCameraReady {
    final c = _cameraController;
    if (c == null) return false;
    final v = c.value;
    return v.isInitialized && !v.hasError;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ watch lifecycle
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ✅ Handle background / foreground transitions safely
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // App going to background – release camera
      _stopTimer();
      _disposeCameraController();
    } else if (state == AppLifecycleState.resumed) {
      // App back – re-init if not processing and controller is null
      if (_processingStage == _ProcessingStage.none &&
          _cameraController == null) {
        _initializeCamera();
      }
    }
  }

  Future<void> _disposeCameraController() async {
    final controller = _cameraController;
    _cameraController = null;
    _isInitialized = false;

    if (controller == null) return;

    try {
      if (controller.value.isRecordingVideo) {
        print('⚠️ Disposing while recording, stopping first...');
        await controller.stopVideoRecording();
      }
    } catch (e) {
      debugPrint('Error stopping recording during dispose: $e');
    }

    try {
      await controller.dispose();
    } catch (e) {
      debugPrint('Error disposing camera controller: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      print('🎥 Starting camera initialization...');

      // Request camera permission
      print('📱 Requesting camera permission...');
      final status = await Permission.camera.request();
      print('✅ Camera permission status: $status');

      if (!mounted) return;

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

      if (!mounted) return;

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

      // ✅ Use a single preset: ResolutionPreset.high (~720p / device-dependent)
      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _cameraController = controller;

      print('⚙️ Initializing camera controller...');
      await controller.initialize();
      print('✅ Camera initialized successfully');

      if (!mounted) {
        await controller.dispose();
        return;
      }

      // ✅ Listen for camera runtime errors
      controller.addListener(() {
        final v = controller.value;
        if (!mounted) return;

        if (v.hasError) {
          print('📛 Camera error: ${v.errorDescription}');
          setState(() {
            _errorMessage =
                'Camera error: ${v.errorDescription ?? "Unknown error"}';
            _isInitialized = false;
          });
        }
      });

      // Set focus mode to auto
      try {
        await controller.setFocusMode(FocusMode.auto);
        print('✅ Focus mode set to auto');
      } catch (e) {
        print('⚠️ Could not set focus mode: $e');
      }

      // Check if flash is available
      final hasFlash = controller.value.flashMode != null;
      print('💡 Flash available: $hasFlash');

      if (hasFlash) {
        await controller.setFlashMode(FlashMode.torch);
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

      if (!mounted) return;

      setState(() {
        _focusPoint = details.localPosition;
        _showFocusCircle = true;
      });

      // Hide focus circle after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
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
          children: const [
            Icon(Icons.settings, color: Color(0xFFD64545), size: 28),
            SizedBox(width: 8),
            Text('Permission Required'),
          ],
        ),
        content: const Text(
          'Camera permission is permanently denied. Please enable it in Settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text(
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
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _recordingSeconds++;
      });

      if (_recordingSeconds >= _maxRecordingDuration) {
        // ⏱️ Auto-stop – uses same guard inside _stopRecording
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
    if (!_isCameraReady) {
      print('🚫 _startRecording called but camera not ready');
      return;
    }

    if (_cameraController != null &&
        !_isRecording &&
        !_isStoppingRecording &&
        _processingStage == _ProcessingStage.none) {
      try {
        print('🎬 Starting video recording...');
        await _cameraController!.startVideoRecording();
        if (!mounted) return;
        setState(() {
          _isRecording = true;
        });
        print('✅ Recording started');
        _startTimer();
      } catch (e) {
        print('❌ Error starting recording: $e');
        _showErrorDialog('Failed to start recording: $e');
      }
    } else {
      print(
        '🚫 _startRecording blocked by state: controller=$_cameraController, '
        'isRecording=$_isRecording, isStopping=$_isStoppingRecording, '
        'processingStage=$_processingStage',
      );
    }
  }

  /// ✅ PPG-safe compression:
  /// - Avoid over-aggressive quality loss
  /// - Prefer mild downscale + medium quality
  /// - Use soft & hard targets to keep enough signal quality
  Future<File> _compressVideoToTarget(String path) async {
    final original = File(path);
    final originalSize = await original.length();
    print('📦 Original file size: $originalSize bytes');

    // 1) If already < soft target → no compression at all
    if (originalSize <= _softMaxFileSizeBytes) {
      print('✅ Original file already under soft target size');
      return original;
    }

    // 2) Define a gentle -> aggressive ordering.
    //    NOTE: We try to stay in "medium" quality as long as possible.
    final qualities = <VideoQuality>[
      // Prefer a fixed resolution around 720p / 480p with medium quality
      VideoQuality.Res640x480Quality, // downscale but decent
      VideoQuality.MediumQuality,
      // Only then try more aggressive low-quality
      VideoQuality.LowQuality,
    ];

    File? bestFile;
    int bestSize = originalSize;

    for (final q in qualities) {
      print('📉 Compressing with quality: $q');

      final info = await VideoCompress.compressVideo(
        path,
        quality: q,
        includeAudio: false,
        deleteOrigin: false,
      );

      if (info == null || info.file == null) {
        print('⚠️ Compression failed for quality: $q');
        continue;
      }

      final f = info.file!;
      final size = await f.length();
      print('➡️ Size after $q: $size bytes');

      // Track best (smallest) file we have seen
      if (size < bestSize) {
        bestFile = f;
        bestSize = size;
      }

      // If we are now below soft target → great, stop here
      if (size <= _softMaxFileSizeBytes) {
        print('✅ Reached soft target size with $q');
        return f;
      }

      // If we are below hard max and this is a "reasonable" quality step,
      // we prefer not to go more aggressive to protect PPG quality.
      final isMediumish =
          q == VideoQuality.Res640x480Quality ||
          q == VideoQuality.MediumQuality;

      if (size <= _hardMaxFileSizeBytes && isMediumish) {
        print(
          '✅ Size is acceptable (< hard max) after $q. '
          'Keeping better PPG signal rather than over-compressing.',
        );
        return f;
      }
    }

    // 3) If we get here, we never reached soft or hard target.
    //    Use the best (smallest) we got, as long as it's not larger than original.
    if (bestFile != null && bestSize < originalSize) {
      print(
        '⚠️ Could not reach target size safely, '
        'using best achieved size: $bestSize bytes',
      );
      return bestFile;
    }

    // 4) Last resort: keep original
    print(
      '⚠️ All compression attempts failed or not beneficial, using original file',
    );
    return original;
  }

  Future<void> _stopRecording() async {
    // ✅ Re-entrancy guard
    if (_isStoppingRecording) {
      print('⏹️ _stopRecording called but already stopping, ignoring...');
      return;
    }

    if (_cameraController == null) {
      print('⏹️ _stopRecording called with null controller, ignoring...');
      return;
    }

    if (!_isRecording) {
      print('⏹️ _stopRecording called but _isRecording=false, ignoring...');
      return;
    }

    _isStoppingRecording = true;
    try {
      print('⏹️ Stopping video recording...');
      _stopTimer();

      final controller = _cameraController!;

      // ✅ Always try to stop and get the file
      _videoFile = await controller.stopVideoRecording();
      print('✅ Recording stopped. File: ${_videoFile!.path}');

      if (_videoFile == null) {
        throw Exception('No video file returned from stopVideoRecording()');
      }

      // ✅ Print original video size
      try {
        final file = File(_videoFile!.path);
        final bytes = await file.length();
        final sizeMB = bytes / (1024 * 1024);
        print(
          '📁 Original video size: $bytes bytes (${sizeMB.toStringAsFixed(2)} MB)',
        );
      } catch (e) {
        print('⚠️ Could not read video file size: $e');
      }

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

      // ✅ Just turn off flash, DO NOT dispose controller here
      try {
        if (controller.value.isInitialized) {
          await controller.setFlashMode(FlashMode.off);
        }
        _isFlashOn = false;
      } catch (e) {
        print('⚠️ Error turning flash off after recording: $e');
      }

      // ✅ Show "compressing" loader immediately
      if (mounted) {
        setState(() {
          _processingStage = _ProcessingStage.compressing;
        });
      }

      // ✅ Compress then send to backend (PPG-safe compression)
      try {
        final compressedFile = await _compressVideoToTarget(_videoFile!.path);
        final compressedBytes = await compressedFile.length();
        final compressedMB = compressedBytes / (1024 * 1024);
        print(
          '📁 Final video size to upload: $compressedBytes bytes (${compressedMB.toStringAsFixed(2)} MB)',
        );

        // ✅ Now switch to "uploading / analyzing" stage
        if (mounted) {
          setState(() {
            _processingStage = _ProcessingStage.uploading;
          });
        }

        await _sendVideoToBackend(compressedFile.path);
      } catch (e) {
        print('⚠️ Compression failed, sending original file: $e');

        if (mounted) {
          setState(() {
            _processingStage = _ProcessingStage.uploading;
          });
        }

        await _sendVideoToBackend(_videoFile!.path);
      }
    } catch (e) {
      print('❌ Error stopping recording: $e');
      if (mounted) {
        setState(() {
          _isRecording = false; // ✅ let user try again
          _processingStage = _ProcessingStage.none;
        });
      }
      _showErrorDialog(
        'Failed to stop recording. Please try again.\n\nDetails: $e',
      );
    } finally {
      _isStoppingRecording = false;
    }
  }

  /// Build Hb status + message + recommendation from a given Hb value.
  /// 👉 Simplified: only uses gender + hb. Ignores age and pregnancy.
  Map<String, dynamic> _buildHbStatusFromValue({
    required double hb,
    int? ageYears, // ignored for now
    String? gender, // ignored for now
  }) {
    // Normalize gender
    final g = gender?.toLowerCase();

    String status;

    if (g == "male") {
      // Adult male ranges
      status = _categorizeWithBands(
        hb,
        normalMin: 13.0,
        normalMax: 17.5,
        mildMin: 11.0,
        mildMax: 11.9,
        moderateMin: 8.0,
        moderateMax: 10.9,
        severeMax: 8.0,
      );
    } else if (g == "female") {
      // Adult female ranges (non-pregnant)
      status = _categorizeWithBands(
        hb,
        normalMin: 12.0,
        normalMax: 15.5,
        mildMin: 11.0,
        mildMax: 11.9,
        moderateMin: 8.0,
        moderateMax: 10.9,
        severeMax: 8.0,
      );
    } else {
      // Generic adult range if gender is unknown
      status = _categorizeSimple(hb, normalMin: 12.0, normalMax: 16.5);
    }

    // Always build rich message + recommendation from status + hb
    final msg = _messages(status, hb);

    return {
      "hb": double.parse(hb.toStringAsFixed(1)),
      "status": status,
      "message": msg["message"],
      "recommendation": msg["recommendation"],
    };
  }

  // ------------------------------------------------------------
  // Helper — Full WHO anemia category logic
  // ------------------------------------------------------------
  String _categorizeWithBands(
    double hb, {
    required double normalMin,
    required double normalMax,
    double? mildMin,
    double? mildMax,
    double? moderateMin,
    double? moderateMax,
    double? severeMax,
  }) {
    if (hb >= normalMin && hb <= normalMax) return "Normal";
    if (mildMin != null && mildMax != null && hb >= mildMin && hb <= mildMax) {
      return "Mild anemia";
    }
    if (moderateMin != null &&
        moderateMax != null &&
        hb >= moderateMin &&
        hb <= moderateMax) {
      return "Moderate anemia";
    }
    if (severeMax != null && hb < severeMax) return "Severe anemia";
    if (hb > normalMax) return "High";
    return "Low";
  }

  // ------------------------------------------------------------
  // Helper — only normal range is defined
  // ------------------------------------------------------------
  String _categorizeSimple(
    double hb, {
    required double normalMin,
    required double normalMax,
  }) {
    if (hb >= normalMin && hb <= normalMax) return "Normal";
    if (hb < normalMin) return "Low";
    return "High";
  }

  // ------------------------------------------------------------
  // Message Builder (rich messages + recommendations)
  // ------------------------------------------------------------
  Map<String, String> _messages(String status, double hb) {
    final s = status.toLowerCase();

    if (s.contains("severe")) {
      return {
        "message":
            "Your hemoglobin level is significantly below the normal range for your age and profile. "
            "This suggests severe anemia, which can cause extreme fatigue, shortness of breath, dizziness, and pale skin.",
        "recommendation":
            "⚠️ Immediate Action Required:\n"
            "• Consult a doctor or visit a hospital as soon as possible for detailed evaluation\n"
            "• Your doctor may prescribe iron supplements, injections, or other specific treatments\n"
            "• Eat iron-rich foods: red meat, liver, spinach, lentils, chickpeas, jaggery\n"
            "• Include vitamin C sources (lemon, orange, amla) to improve iron absorption\n"
            "• Avoid tea/coffee close to meals as they reduce iron absorption\n"
            "• Do not self-medicate with high-dose iron without medical advice",
      };
    }

    if (s.contains("moderate")) {
      return {
        "message":
            "Your hemoglobin level is moderately below the expected range. This can cause tiredness, weakness, headaches, "
            "reduced exercise capacity, and difficulty concentrating.",
        "recommendation":
            "⚠️ Medical Attention Recommended:\n"
            "• Book an appointment with your doctor for further tests and a proper diagnosis\n"
            "• Increase intake of iron-rich foods: eggs, fish, leafy greens, beans, peas, dry fruits\n"
            "• Add folate-rich foods: broccoli, beetroot, peas, fortified cereals\n"
            "• Ensure adequate vitamin B12: milk, curd, paneer, eggs, or fortified foods\n"
            "• Get enough rest and avoid very strenuous activity until levels improve\n"
            "• Follow up with repeat Hb tests as advised by your doctor",
      };
    }

    if (s.contains("mild") ||
        s.contains("borderline low") ||
        s.contains("mild anemia") ||
        s == "low") {
      return {
        "message":
            "Your hemoglobin level is slightly below the normal range. You may feel mild tiredness, weakness, or reduced stamina, "
            "especially during physical activity.",
        "recommendation":
            "💡 Dietary & Lifestyle Improvements Suggested:\n"
            "• Focus on iron-rich foods: lean meat, chicken, tofu, spinach, pumpkin seeds, lentils\n"
            "• Combine iron sources with vitamin C (lemon, oranges, guava, tomatoes) to improve absorption\n"
            "• Include dark leafy greens and whole grains regularly in your meals\n"
            "• Avoid skipping meals and try to maintain a regular, balanced diet\n"
            "• If symptoms persist (fatigue, paleness, breathlessness), consult a doctor for evaluation\n"
            "• Periodically recheck your Hb level as advised",
      };
    }

    if (s.contains("normal")) {
      return {
        "message":
            "Your hemoglobin level is within the healthy range for your age and profile. This suggests good oxygen-carrying capacity "
            "and generally adequate nutrition.",
        "recommendation":
            "✅ Maintain Healthy Habits:\n"
            "• Continue a balanced diet with sufficient iron, vitamin B12, and folate\n"
            "• Include protein sources: pulses, dairy products, eggs, chicken, fish, nuts and seeds\n"
            "• Stay physically active with regular, moderate exercise\n"
            "• Drink enough water throughout the day and sleep 7–9 hours daily (for adults)\n"
            "• Go for regular health checkups and repeat Hb testing as recommended\n"
            "• No need for iron supplements unless specifically advised by your doctor",
      };
    }

    if (s.contains("high") ||
        s.contains("elevated") ||
        s.contains("above normal") ||
        s.contains("polycythemia")) {
      if (hb >= 18.0) {
        return {
          "message":
              "Your hemoglobin level is significantly above the normal range. This can increase blood thickness and may be associated "
              "with conditions such as polycythemia, which can increase the risk of blood clots, headaches, and dizziness.",
          "recommendation":
              "⚠️ Medical Consultation Required:\n"
              "• Consult a doctor or specialist as soon as possible for detailed evaluation\n"
              "• Avoid taking any iron supplements unless they are clearly prescribed\n"
              "• Drink adequate water to stay well-hydrated and reduce blood thickening\n"
              "• Avoid smoking and limit alcohol intake\n"
              "• Watch for symptoms like headaches, vision changes, chest pain, or breathlessness and seek urgent care if present",
        };
      } else {
        return {
          "message":
              "Your hemoglobin level is above the usual range. This can sometimes be due to dehydration, smoking, high altitude, "
              "or an underlying medical condition.",
          "recommendation":
              "💡 Recommended Actions:\n"
              "• Increase your daily fluid intake unless your doctor has restricted fluids\n"
              "• Avoid unnecessary iron supplementation or high-iron tonics\n"
              "• If you smoke, consider quitting and discuss support options with your doctor\n"
              "• Schedule a consultation with your doctor to understand the cause and need for further tests\n"
              "• Recheck hemoglobin after adequate hydration or as advised by your physician",
        };
      }
    }

    return {
      "message":
          "Your hemoglobin level has been calculated and categorized, but the detailed category label is not recognized by the app.",
      "recommendation":
          "ℹ️ General Advice:\n"
          "• Discuss this report with your doctor for personalized interpretation\n"
          "• Maintain a balanced diet rich in iron, vitamin B12, and folate\n"
          "• Avoid self-medicating with iron or other supplements without medical guidance\n"
          "• Repeat testing or additional investigations may be suggested by your healthcare provider",
    };
  }

  Map<String, dynamic> _error(double hb, String msg) {
    return {
      "hb": double.parse(hb.toStringAsFixed(1)),
      "status": "error",
      "message": msg,
      "recommendation": "",
    };
  }

  Future<void> _saveScanResultToHistory({
    required double hb,
    required double hrBpm,
    required String status,
    required String message,
    required String recommendation,
    required String age,
    required String weight,
    required String gender,
    required String mobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> rawHistory = prefs.getStringList('scanHistory') ?? [];

    final now = DateTime.now().toIso8601String();

    final newRecord = {
      'hb': hb,
      'hr_bpm': hrBpm,
      'status': status,
      'message': message,
      'recommendation': recommendation,
      'date': now,
      'age': age,
      'weight': weight,
      'gender': gender,
      'mobile': mobile,
    };

    rawHistory.insert(0, jsonEncode(newRecord));
    await prefs.setStringList('scanHistory', rawHistory);

    await prefs.setDouble('lastHb', hb);
    await prefs.setString('lastStatus', status);
    await prefs.setString('lastDate', now);
  }

  Future<void> _sendVideoToBackend(String videoPath) async {
    // We are already in uploading stage; just ensure camera UI is not used
    setState(() {
      _isInitialized = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final gender = prefs.getString('gender') ?? '';
      final age = prefs.getString('age') ?? '';
      final weight = prefs.getString('weight') ?? '';
      final mobile = prefs.getString('mobile') ?? '';

      if (gender.isEmpty || age.isEmpty || weight.isEmpty) {
        throw Exception(
          'Missing user data (gender/age/weight). Please go back and fill the form again.',
        );
      }

      print('📤 Uploading video from: $videoPath');

      final uri = Uri.parse('https://hbpredictionapp.online/predict');
      final request = http.MultipartRequest('POST', uri)
        ..fields['gender'] = gender.toLowerCase()
        ..fields['age'] = age
        ..fields['weight'] = weight
        ..files.add(
          await http.MultipartFile.fromPath(
            'video',
            videoPath,
            filename: 'scan.mp4',
            contentType: MediaType('video', 'mp4'),
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Server error (${response.statusCode}): ${response.body}',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      final hbPred = (data['hb_pred'] as num).toDouble();
      final hrBpm = (data['hr_bpm'] as num).toDouble();

      final hbStatus = _buildHbStatusFromValue(
        hb: hbPred,
        ageYears: int.tryParse(age),
        gender: gender,
      );

      print('ℹ️ hbStatus map: $hbStatus');

      double hbValue;
      final dynamic rawHb = hbStatus['hb'];
      if (rawHb is num) {
        hbValue = rawHb.toDouble();
      } else {
        hbValue = hbPred;
      }

      final String status = hbStatus['status']?.toString() ?? 'Unknown';
      final String message =
          hbStatus['message']?.toString() ?? 'No detailed message.';
      final String recommendation =
          hbStatus['recommendation']?.toString() ?? '';

      await _saveScanResultToHistory(
        hb: hbValue,
        hrBpm: hrBpm,
        status: status,
        message: message,
        recommendation: recommendation,
        age: age,
        weight: weight,
        gender: gender,
        mobile: mobile,
      );

      if (mounted) {
        setState(() {
          _processingStage = _ProcessingStage.none;
        });
      }

      print('✅ Upload + prediction complete');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HemoglobinResultScreen(
              hemoglobinLevel: hbValue.toStringAsFixed(1),
              status: status,
              message: message,
              recommendation: recommendation,
              age: age,
              weight: weight,
              gender: gender,
              hrBpm: hrBpm.toStringAsFixed(0),
              mobile: mobile,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processingStage = _ProcessingStage.none;
        });
      }
      print('❌ Error uploading video / calling API: $e');
      _showErrorDialog('Error uploading video: $e');
    }
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
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
            child: const Text('OK', style: TextStyle(color: Color(0xFFD64545))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    print('🧹 Disposing camera resources...');
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _disposeCameraController(); // async cleanup
    VideoCompress.dispose(); // 🔚 cleanup compression isolates (no await)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isReady = _isCameraReady;
    final bool isProcessing = _processingStage != _ProcessingStage.none;
    final bool isCompressing = _processingStage == _ProcessingStage.compressing;

    return WillPopScope(
      onWillPop: () async {
        if (_isRecording || _isStoppingRecording || isProcessing) {
          // prevent popping while recording or processing
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (!isProcessing)
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
                            icon: const Icon(
                              Icons.arrow_back,
                              size: 28,
                              color: Colors.white,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 48),
                          IconButton(
                            onPressed: _toggleFlash,
                            icon: Icon(
                              _isFlashOn ? Icons.flash_on : Icons.flash_off,
                              size: 28,
                              color: (_isFlashOn ? Colors.amber : Colors.white),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Instructions - Compact
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8,
                      ),
                      child: const Text(
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
                          if (_isRecording)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                'Time remaining: ${_formatTime(_maxRecordingDuration - _recordingSeconds)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),

                          // Show “setting up camera” if not ready yet
                          if (!isReady && _errorMessage == null)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 12.0,
                                top: 4,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFFD64545),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Setting up the camera...',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed:
                                  (_isRecording ||
                                      _isStoppingRecording ||
                                      !isReady ||
                                      _errorMessage != null)
                                  ? null
                                  : _startRecording,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD64545),
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
                                style: const TextStyle(
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

            if (isProcessing)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          color: Color(0xFFD64545),
                          strokeWidth: 6,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        isCompressing
                            ? 'Preparing Video...'
                            : 'Analyzing Video...',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isCompressing
                            ? 'Compressing your scan so we can securely\nupload it to our server.'
                            : 'Please wait while we process\nyour hemoglobin reading',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFD64545),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.transparent,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isCompressing
                                  ? 'Optimizing video for upload...'
                                  : 'This may take up to 30 seconds',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
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
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Color(0xFFD64545),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                    });
                    _initializeCamera();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD64545),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isCameraReady || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
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
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
              if (_isCameraReady && _errorMessage == null)
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD64545),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              if (_showFocusCircle && _focusPoint != null)
                Positioned(
                  left: _focusPoint!.dx - 40,
                  top: _focusPoint!.dy - 40,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
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
                          child: const Icon(
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
