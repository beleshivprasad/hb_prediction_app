import 'package:flutter/material.dart';
import 'package:hemoglobin_predictor/pages/scan_history.dart';
import 'package:hemoglobin_predictor/pages/start_recording.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartScan extends StatefulWidget {
  const StartScan({super.key});

  @override
  State<StartScan> createState() => _StartScanState();
}

class _StartScanState extends State<StartScan> {
  int _selectedIndex = 0;
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String? _selectedSkinColor;

  // Last saved result
  double? lastHb;
  String? lastStatus;
  String? lastDate;

  final List<String> skinColors = ['Fair', 'Medium', 'Dusky', 'Dark'];

  @override
  void initState() {
    super.initState();
    _resetInputFields(); // ✅ Reset fields on first load or return
    _loadLastResult(); // Load only the last scan result
  }

  // ✅ This will be called whenever the page becomes visible again
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh last scan result when page becomes visible
    _loadLastResult();
  }

  // ✅ Reset input fields to empty
  void _resetInputFields() {
    setState(() {
      _ageController.clear();
      _weightController.clear();
      _selectedSkinColor = null;
    });
  }

  // ✅ Load only last scan result (not user inputs)
  Future<void> _loadLastResult() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      lastHb = prefs.getDouble('lastHb');
      lastStatus = prefs.getString('lastStatus');
      lastDate = prefs.getString('lastDate');
    });
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('age', _ageController.text);
    await prefs.setString('weight', _weightController.text);
    if (_selectedSkinColor != null) {
      await prefs.setString('skinColor', _selectedSkinColor!);
    }
  }

  void _onStartScan() async {
    if (_ageController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _selectedSkinColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Please fill all fields before starting scan'),
              ),
            ],
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    await _saveUserData();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StartRecording()),
    );

    // ✅ Reset fields after returning from recording
    _resetInputFields();
    
    // ✅ Reload the last scan result after returning
    if (result != null || mounted) {
      await _loadLastResult();
    }
  }

  // ✅ Check if any field has data
  bool get _hasInputData {
    return _ageController.text.isNotEmpty ||
        _weightController.text.isNotEmpty ||
        _selectedSkinColor != null;
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    final lower = status.toLowerCase();
    if (lower == 'normal') return Colors.green;
    if (lower == 'low') return Colors.orange;
    return Colors.red;
  }

  String _getRelativeTime(String? dateStr) {
    if (dateStr == null) return '';
    
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes < 1) return 'Just now';
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      } else {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // 🩸 Welcome Text with Reset Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Welcome, User',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  // ✅ Reset Button (only visible if fields have data)
                  if (_hasInputData)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Clear All Fields?'),
                              content: const Text(
                                'This will reset age, weight, and skin color.',
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _resetInputFields();
                                  },
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(color: Color(0xFFD64545)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.refresh,
                          color: Color(0xFFD64545),
                        ),
                        tooltip: 'Clear all fields',
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 32),

              // 🎂 Age Input
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Age',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _ageController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _ageController.clear();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // ⚖️ Weight Input
              TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  prefixIcon: const Icon(Icons.monitor_weight_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _weightController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _weightController.clear();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // 🎨 Skin Color Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSkinColor,
                decoration: InputDecoration(
                  labelText: 'Skin Color',
                  prefixIcon: const Icon(Icons.color_lens_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: skinColors
                    .map(
                      (color) =>
                          DropdownMenuItem(value: color, child: Text(color)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSkinColor = value;
                  });
                },
              ),

              const SizedBox(height: 32),

              // 🔴 Start Scan Button
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton.icon(
                  onPressed: _onStartScan,
                  icon: const Icon(Icons.play_circle_outline, size: 28),
                  label: const Text(
                    'Start Scan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

              const SizedBox(height: 40),

              // 📊 Last Scan Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: lastHb != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Last Scan Result',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(lastStatus)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  lastStatus?.toUpperCase() ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(lastStatus),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD64545)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.bloodtype_rounded,
                                  color: Color(0xFFD64545),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${lastHb!.toStringAsFixed(1)} g/dL',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD64545),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getRelativeTime(lastDate),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  lastDate != null
                                      ? (() {
                                          final dt =
                                              DateTime.tryParse(lastDate!);
                                          if (dt == null) return '-';
                                          final months = [
                                            'Jan',
                                            'Feb',
                                            'Mar',
                                            'Apr',
                                            'May',
                                            'Jun',
                                            'Jul',
                                            'Aug',
                                            'Sep',
                                            'Oct',
                                            'Nov',
                                            'Dec',
                                          ];
                                          final day =
                                              dt.day.toString().padLeft(2, '0');
                                          final month = months[dt.month - 1];
                                          final year = dt.year;
                                          int hour = dt.hour;
                                          final minute = dt.minute
                                              .toString()
                                              .padLeft(2, '0');
                                          final ampm =
                                              hour >= 12 ? 'PM' : 'AM';
                                          hour = hour % 12;
                                          if (hour == 0) hour = 12;
                                          final hourStr =
                                              hour.toString().padLeft(2, '0');
                                          return '$day $month $year • $hourStr:$minute $ampm';
                                        })()
                                      : '-',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Icon(
                            Icons.pending_actions_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No previous scan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Complete your first scan to see results here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),

      // 🧭 Bottom Navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) async {
            if (index == 1) {
              // Navigate to history and refresh on return
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScanHistoryPage(),
                ),
              );
              // Refresh last scan when returning from history
              _loadLastResult();
            } else if (index == 0) {
              // Already on home, just refresh
              _loadLastResult();
            }
            setState(() {
              _selectedIndex = 0; // Always keep home selected when on this page
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFD64545),
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 14,
          unselectedFontSize: 14,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history, size: 28),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}