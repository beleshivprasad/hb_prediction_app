import 'package:flutter/material.dart';
import 'package:hemoglobin_predictor/pages/start_scan.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ added import

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// ✅ Function to clear stored user data (age, weight, etc.)
  Future<void> _resetUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('age');
    await prefs.remove('weight');
    await prefs.remove('skinColor');
    await prefs.remove('lastHb');
    await prefs.remove('lastStatus');
    await prefs.remove('lastDate');
  }

  /// ✅ Modified navigation logic to handle reset when coming back from result page
  Future<void> _navigateToStartScan() async {
    final result = await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const StartScan()),
    );

    // 👇 Reset data only if user came back from result screen intentionally
    if (result == 'reset') {
      await _resetUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE88B8B), Color(0xFFF5C5C5), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Blood drop icon with phone
              Container(
                width: 120,
                height: 140,
                decoration: const BoxDecoration(
                  color: Color(0xFFD64545),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(60),
                    bottom: Radius.circular(60),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 50,
                    height: 70,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFFD64545),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          width: 20,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Title
              const Text(
                'HemoCheck AI',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD64545),
                ),
              ),
              const SizedBox(height: 16),

              // Subtitle
              const Text(
                'Non-Invasive Hemoglobin\nEstimation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 3),

              // Get Started Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _navigateToStartScan, // ✅ updated
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD64545),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
