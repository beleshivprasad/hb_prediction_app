import 'package:flutter/material.dart';

class ScanDetailsPage extends StatelessWidget {
  final Map<String, dynamic> record;

  const ScanDetailsPage({super.key, required this.record});

  Color _getStatusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('normal')) return Colors.green;
    if (lower.contains('mild')) return Colors.orange;
    if (lower.contains('moderate') || lower.contains('severe')) {
      return Colors.red.shade700;
    }
    if (lower.contains('low')) return Colors.orange;
    if (lower.contains('high')) return Colors.red;
    return Colors.grey;
  }

  IconData _getStatusIcon(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('normal')) return Icons.check_circle_outline;
    if (lower.contains('low') || lower.contains('anemia')) {
      return Icons.arrow_downward_rounded;
    }
    if (lower.contains('high')) return Icons.arrow_upward_rounded;
    return Icons.bloodtype_rounded;
  }

  String ceilValue(dynamic value) {
    if (value == null) return "--";

    final num? number = num.tryParse(value.toString());
    if (number == null) return "--";

    return number.ceil().toString();
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
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
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = dt.year;
      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final hourStr = hour.toString().padLeft(2, '0');
      return '$day $month $year $hourStr:$minute $ampm';
    } catch (_) {
      return 'Unknown Date';
    }
  }

  String _relativeTime(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          if (diff.inMinutes < 1) return 'Just now';
          return '${diff.inMinutes} min ago';
        }
        return '${diff.inHours} h ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else if (diff.inDays < 30) {
        final weeks = (diff.inDays / 7).floor();
        return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      } else {
        final months = (diff.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hb = record['hb']?.toString() ?? 'N/A';
    final status = (record['status'] ?? 'Unknown').toString();
    final date = (record['date'] ?? '').toString();
    final message = (record['message'] ?? 'No message available.').toString();
    final recommendation = (record['recommendation'] ?? '').toString();

    // Newly saved fields (may be absent in older records)
    final age = record['age']?.toString() ?? '';
    final weight = record['weight']?.toString() ?? '';
    final gender = record['gender']?.toString() ?? '';
    final hrBpm = record['hr_bpm']?.toString() ?? '';
    final mobile = record['mobile']?.toString() ?? '';

    final formattedDate = date.isNotEmpty ? _formatDate(date) : 'Unknown Date';
    final relative = date.isNotEmpty ? _relativeTime(date) : '';

    final statusColor = _getStatusColor(status);

    final hasSummaryInfo =
        age.isNotEmpty ||
        gender.isNotEmpty ||
        weight.isNotEmpty ||
        mobile.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Scan Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFD64545),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
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
                      formattedDate,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                      ),
                    ),
                    if (relative.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        relative,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],

                    // 🔹 compact chips for Age / Gender / Weight / Mobile
                    if (hasSummaryInfo) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            if (age.isNotEmpty)
                              _buildSummaryChip(
                                icon: Icons.calendar_today,
                                label: "Age: $age",
                              ),
                            if (gender.isNotEmpty)
                              _buildSummaryChip(
                                icon: Icons.person_outline,
                                label: "Gender: $gender",
                              ),
                            if (weight.isNotEmpty)
                              _buildSummaryChip(
                                icon: Icons.monitor_weight_outlined,
                                label: "Weight: $weight kg",
                              ),
                            if (mobile.isNotEmpty)
                              _buildSummaryChip(
                                icon: Icons.phone_android,
                                label: mobile,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 📊 Result Card
              Container(
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
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(status),
                        color: statusColor,
                        size: 40,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔢 Hemoglobin Value
                    Text(
                      "$hb g/dL",
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD64545),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🧍 Personal Info Section (detailed)
                    if (age.isNotEmpty ||
                        weight.isNotEmpty ||
                        gender.isNotEmpty ||
                        hrBpm.isNotEmpty ||
                        mobile.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                if (age.isNotEmpty)
                                  _buildInfoTile(
                                    "Age",
                                    age,
                                    Icons.calendar_today,
                                  ),
                                if (gender.isNotEmpty)
                                  _buildInfoTile(
                                    "Gender",
                                    gender,
                                    Icons.person_outline,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                if (weight.isNotEmpty)
                                  _buildInfoTile(
                                    "Weight",
                                    "$weight kg",
                                    Icons.monitor_weight_outlined,
                                  ),
                                if (hrBpm.isNotEmpty)
                                  _buildInfoTile(
                                    "Heart Rate",
                                    "${ceilValue(hrBpm)} bpm",
                                    Icons.favorite_border,
                                  ),
                              ],
                            ),
                            if (mobile.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.phone_android,
                                    size: 18,
                                    color: Color(0xFFD64545),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    mobile,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),

                    // 💬 Message Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        message,
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

              // 💡 Recommendations Section (if available)
              if (recommendation.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.08),
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
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lightbulb_outline_rounded,
                              color: statusColor,
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
                            color: statusColor.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: _buildRecommendationContent(
                          recommendation,
                          statusColor,
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
              ],

              const SizedBox(height: 24),

              // 🔙 Back Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Back to History',
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

  /// Chips in the header for quick summary
  Widget _buildSummaryChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Nicely formats all recommendation lines (title + bullet list)
  Widget _buildRecommendationContent(String recommendation, Color accent) {
    final lines = recommendation
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return Text(
        recommendation,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[800],
          height: 1.8,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final title = lines.first;
    final bullets = lines.length > 1 ? lines.sublist(1) : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: accent,
            height: 1.4,
          ),
        ),
        if (bullets.isNotEmpty) const SizedBox(height: 10),
        ...bullets.map((line) {
          String cleaned = line;
          if (cleaned.startsWith('•')) {
            cleaned = cleaned.substring(1).trim();
          } else if (cleaned.startsWith('-')) {
            cleaned = cleaned.substring(1).trim();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(
                    cleaned,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
