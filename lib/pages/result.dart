import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HemoglobinResultScreen extends StatefulWidget {
  final String hemoglobinLevel;
  final String status;
  final String message;
  final String age;
  final String weight;
  final String gender;
  final String hrBpm;
  final String mobile;
  final String recommendation;

  const HemoglobinResultScreen({
    super.key,
    required this.age,
    required this.weight,
    required this.gender,
    required this.hrBpm,
    required this.mobile,
    required this.hemoglobinLevel,
    required this.status,
    required this.message,
    required this.recommendation,
  });

  @override
  State<HemoglobinResultScreen> createState() => _HemoglobinResultScreenState();
}

class _HemoglobinResultScreenState extends State<HemoglobinResultScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _resultKey = GlobalKey();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  /// ✅ Clear stored user data (age, weight, gender, mobile)
  Future<void> _resetUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('age');
    await prefs.remove('weight');
    await prefs.remove('gender');
    await prefs.remove('mobile');
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    if (widget.status.toLowerCase() == 'normal') return Colors.green;
    if (widget.status.toLowerCase() == 'low') return Colors.orange;
    return Colors.red;
  }

  IconData _getStatusIcon() {
    if (widget.status.toLowerCase() == 'normal') {
      return Icons.check_circle_outline;
    }
    if (widget.status.toLowerCase() == 'low') {
      return Icons.arrow_downward_rounded;
    }
    return Icons.arrow_upward_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 🌅 Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "HemoCheck Result",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Your personalized hemoglobin analysis",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 📊 Result Card
                RepaintBoundary(
                  key: _resultKey,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Status Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getStatusColor().withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getStatusIcon(),
                            color: _getStatusColor(),
                            size: 40,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          "${widget.hemoglobinLevel} g/dL",
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD64545),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor().withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 🧍 Personal Info Section (Age, Weight, Gender, HR)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildInfoTile(
                                    "Age",
                                    widget.age,
                                    Icons.calendar_today,
                                  ),
                                  _buildInfoTile(
                                    "Weight",
                                    "${widget.weight} kg",
                                    Icons.monitor_weight_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildInfoTile(
                                    "Gender",
                                    widget.gender,
                                    Icons.person_outline,
                                  ),
                                  _buildInfoTile(
                                    "Heart Rate",
                                    "${widget.hrBpm} bpm",
                                    Icons.favorite_border,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 📱 Mobile (small line below info tiles)
                        if (widget.mobile.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.phone_android,
                                    size: 18,
                                    color: Color(0xFFD64545),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.mobile,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // 📄 Message
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.message,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 💡 Recommendations Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor().withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _getStatusColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lightbulb_outline_rounded,
                              color: _getStatusColor(),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Recommendations",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor().withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          widget.recommendation,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Disclaimer
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber[800],
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "This is for informational purposes only. Always consult a healthcare professional for medical advice.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 🏠 Back to Home Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _resetUserData();
                      if (!mounted) return;
                      Navigator.pop(context, 'reset');
                    },
                    icon: const Icon(Icons.home_rounded, color: Colors.white),
                    label: const Text(
                      'Back to Home',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD64545),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Small widget for displaying info tiles
  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFD64545), size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
