import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../services/api_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final int studentId;
  final String? studentName;

  const StudentDetailScreen({
    super.key,
    required this.studentId,
    this.studentName,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _api.getStudentProfile(widget.studentId);
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _confirmToggleStatus() {
    if (_profileData == null) return;
    final st = _profileData!['student'];
    final bool isActive = st['status'] == 'ACTIVE';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? 'Deactivate Student?' : 'Activate Student?'),
        content: Text(
          isActive
              ? "Deactivating ${st['name']} will preserve all historical rewards and event records intact in the system."
              : "Reactivating ${st['name']} will allow them to receive event rewards and participate in active distributions.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? AppColors.statusOutOfStock : AppColors.statusDistributed,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (isActive) {
                  await _api.deactivateStudent(widget.studentId);
                } else {
                  await _api.activateStudent(widget.studentId);
                }
                _loadProfile();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: Text(isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }

  void _showEditStudentDialog() {
    if (_profileData == null) return;
    final st = _profileData!['student'];

    final nameCtrl = TextEditingController(text: st['name'] ?? '');
    final rollCtrl = TextEditingController(text: st['roll_number'] ?? '');
    final emailCtrl = TextEditingController(text: st['email'] ?? '');
    final phoneCtrl = TextEditingController(text: st['phone'] ?? '');
    int sem = st['current_semester'] ?? 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Edit Student Details', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rollCtrl,
                  decoration: const InputDecoration(labelText: 'University Roll Number *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: sem,
                  decoration: const InputDecoration(labelText: 'Semester Level'),
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('3rd Semester (Odd Scheme)')),
                    DropdownMenuItem(value: 4, child: Text('4th Semester (Even Scheme)')),
                    DropdownMenuItem(value: 5, child: Text('5th Semester (Odd Scheme)')),
                    DropdownMenuItem(value: 6, child: Text('6th Semester (Even Scheme)')),
                    DropdownMenuItem(value: 7, child: Text('7th Semester (Odd Scheme)')),
                    DropdownMenuItem(value: 8, child: Text('8th Semester (Even Scheme)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => sem = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || rollCtrl.text.trim().isEmpty) return;
                try {
                  await _api.updateStudent(widget.studentId, {
                    'name': nameCtrl.text.trim(),
                    'roll_number': rollCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'current_semester': sem,
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadProfile();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPromoteStudentDialog() {
    if (_profileData == null) return;
    final st = _profileData!['student'];
    final int currentSem = st['current_semester'] ?? 3;
    final int nextSem = currentSem + 1;

    if (nextSem > 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Student is already in 8th Semester (Final).")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promote Student Semester'),
        content: Text(
          "Advance ${st['name']} from ${currentSem}th Semester to ${nextSem}th Semester?\n\nAll existing distribution and reward history remains permanently intact.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.updateStudent(widget.studentId, {
                  'current_semester': nextSem,
                });
                _loadProfile();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: Text('Promote to ${nextSem}th Sem'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStudent() {
    if (_profileData == null) return;
    final st = _profileData!['student'];
    final history = (_profileData!['reward_history'] as List<dynamic>?) ?? [];

    if (history.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete Student'),
          content: Text(
            "This student has ${history.length} historical reward distribution record(s). To preserve audit integrity, records cannot be deleted. You can Deactivate the student instead.",
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student Record?'),
        content: Text("Are you sure you want to permanently delete ${st['name']} (${st['student_id']})?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusOutOfStock),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteStudent(widget.studentId);
                if (mounted) {
                  Navigator.pop(context, true); // Return to student list with refresh signal
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.studentName ?? "Student Record";

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primaryOrange),
            tooltip: "Edit Student",
            onPressed: _profileData != null ? _showEditStudentDialog : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryNavy),
            tooltip: "Refresh Profile",
            onPressed: _loadProfile,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.statusOutOfStock),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGray),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final d = _profileData!;
    final st = d['student'] as Map<String, dynamic>;
    final history = (d['reward_history'] as List<dynamic>?) ?? [];
    final wins = (d['wins'] as List<dynamic>?) ?? [];
    final bool isActive = st['status'] == 'ACTIVE';
    final int totalRewards = d['total_rewards_received'] ?? history.length;
    final int totalEvents = d['total_events_attended'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: AppColors.primaryOrange,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Hero Profile Card
            _buildHeroProfileCard(st, isActive),
            const SizedBox(height: 16),

            // Metrics Summary Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: "Rewards Received",
                    value: "$totalRewards",
                    icon: Icons.card_giftcard,
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: "Competitions Won",
                    value: "${wins.length}",
                    icon: Icons.emoji_events,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: "Events Attended",
                    value: "$totalEvents",
                    icon: Icons.event_available,
                    color: AppColors.statusDistributed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Promotion Action Bar
            _buildSemesterBar(st),
            const SizedBox(height: 20),

            // Competition Wins Section (if any)
            if (wins.isNotEmpty) ...[
              _buildWinsSection(wins),
              const SizedBox(height: 20),
            ],

            // Historical Rewards Timeline (Core feature)
            _buildHistoricalRewardsSection(history),
            const SizedBox(height: 24),

            // Student Status and Safe Actions
            _buildDangerZoneSection(st, isActive, history.isEmpty),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroProfileCard(Map<String, dynamic> st, bool isActive) {
    final String name = st['name'] ?? '';
    final String initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'S';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryNavy, AppColors.primaryOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.statusDistributed.withOpacity(0.12)
                                : AppColors.statusOutOfStock.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'ACTIVE' : 'INACTIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isActive ? AppColors.statusDistributed : AppColors.statusOutOfStock,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            st['student_id'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Roll: ${st['roll_number'] ?? ''}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Bio details
          Row(
            children: [
              const Icon(Icons.school, size: 16, color: AppColors.textGray),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${st['branch'] ?? 'CSE'} • Batch ${st['batch'] ?? '2025'}",
                  style: const TextStyle(fontSize: 13, color: AppColors.textGray),
                ),
              ),
            ],
          ),
          if (st['email'] != null && st['email'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 16, color: AppColors.textGray),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    st['email'],
                    style: const TextStyle(fontSize: 13, color: AppColors.textGray),
                  ),
                ),
              ],
            ),
          ],
          if (st['phone'] != null && st['phone'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: AppColors.textGray),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    st['phone'],
                    style: const TextStyle(fontSize: 13, color: AppColors.textGray),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterBar(Map<String, dynamic> st) {
    final int sem = st['current_semester'] ?? 3;
    final String scheme = (sem % 2 == 1) ? 'Odd Scheme' : 'Even Scheme';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.timeline, color: AppColors.primaryNavy, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Current: ${sem}th Semester",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryNavy),
                  ),
                  Text(
                    scheme,
                    style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                ],
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _showPromoteStudentDialog,
            icon: const Icon(Icons.arrow_upward, size: 14, color: AppColors.primaryOrange),
            label: const Text("Promote", style: TextStyle(color: AppColors.primaryOrange, fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryOrange),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinsSection(List<dynamic> wins) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppColors.primaryOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                "Competition Wins (${wins.length})",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...wins.map((w) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLightOrange.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryOrange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star, size: 14, color: AppColors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${w['position']} in ${w['event_name']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          if (w['prize_title'] != null && w['prize_title'].toString().isNotEmpty)
                            Text(
                              "Prize: ${w['prize_title']}",
                              style: const TextStyle(fontSize: 12, color: AppColors.primaryOrange, fontWeight: FontWeight.w600),
                            ),
                          if (w['notes'] != null && w['notes'].toString().isNotEmpty)
                            Text(
                              w['notes'],
                              style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildHistoricalRewardsSection(List<dynamic> history) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_edu, color: AppColors.primaryNavy, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Historical Rewards (${history.length})",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Never Erased",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGray),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.textGray.withOpacity(0.4)),
                  const SizedBox(height: 8),
                  const Text(
                    "No rewards distributed yet",
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Rewards distributed to this student during events stay preserved across all semesters.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final h = history[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.statusDistributed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle, color: AppColors.statusDistributed, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    "${h['quantity']}x ${h['item_name']}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryOrange.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${h['semester_at_distribution']}th Sem",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${h['event_name']} (${h['session_at_distribution'] ?? ''})",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGray),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.person_pin, size: 12, color: AppColors.textGray),
                                const SizedBox(width: 4),
                                Text(
                                  "By ${h['distributed_by'] ?? 'Coordinator'}",
                                  style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDate(h['distributed_at'] ?? ''),
                                  style: const TextStyle(fontSize: 10, color: AppColors.textGray),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneSection(Map<String, dynamic> st, bool isActive, bool canDelete) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Account Actions & Audit",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _confirmToggleStatus,
                  icon: Icon(
                    isActive ? Icons.person_off_outlined : Icons.person_add_outlined,
                    size: 16,
                    color: isActive ? AppColors.statusOutOfStock : AppColors.statusDistributed,
                  ),
                  label: Text(
                    isActive ? "Deactivate" : "Activate",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppColors.statusOutOfStock : AppColors.statusDistributed,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isActive ? AppColors.statusOutOfStock : AppColors.statusDistributed,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _confirmDeleteStudent,
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.statusOutOfStock),
                    label: const Text(
                      "Delete",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.statusOutOfStock),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.statusOutOfStock),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
