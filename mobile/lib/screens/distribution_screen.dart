import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/api_service.dart';

class DistributionScreen extends StatefulWidget {
  final int? initialEventId;
  const DistributionScreen({super.key, this.initialEventId});

  @override
  State<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends State<DistributionScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _events = [];
  int? _selectedEventId;
  Map<String, dynamic>? _matrixData;
  bool _isLoading = true;
  String? _statusFilter = 'ALL';
  int? _semesterFilter;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final evList = await _api.getEvents(status: 'ALL');
      setState(() {
        _events = evList;
        if (_events.isNotEmpty) {
          _selectedEventId = widget.initialEventId ?? _events.first['id'];
        }
      });
      if (_selectedEventId != null) {
        await _loadMatrix();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMatrix() async {
    if (_selectedEventId == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await _api.getEventDistributionMatrix(
        _selectedEventId!,
        semester: _semesterFilter,
        search: _searchController.text.trim(),
        statusFilter: _statusFilter == 'ALL' ? null : _statusFilter,
      );
      setState(() {
        _matrixData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _distributeItem(int studentId, int eventInventoryId, String studentName, String itemName) async {
    try {
      final res = await _api.saveDistribution(studentId, eventInventoryId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusDistributed,
            content: Text("✓ Reward recorded: $studentName received $itemName"),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadMatrix();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Distribution Notice', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  Future<void> _undoDistribution(int distributionId, String studentName, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo Distribution?'),
        content: Text('Reversing this will return 1 unit of $itemName back to event inventory. Confirm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusOutOfStock),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Undo'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.reverseDistribution(distributionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Distribution undone for $studentName.")),
          );
          _loadMatrix();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = (_matrixData?['rows'] as List<dynamic>?) ?? [];
    final summary = _matrixData?['summary'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Rewards & Distribution", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryNavy),
            onPressed: _loadMatrix,
          ),
        ],
      ),
      body: Column(
        children: [
          // Event Selector & Search Bar
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Event", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: _selectedEventId,
                  isExpanded: true,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                  items: _events.map<DropdownMenuItem<int>>((ev) {
                    return DropdownMenuItem<int>(
                      value: ev['id'],
                      child: Text("${ev['event_uid']} • ${ev['name']}", overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedEventId = val);
                    _loadMatrix();
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _loadMatrix(),
                  decoration: InputDecoration(
                    hintText: 'Search student by name, S60 ID, or roll...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadMatrix();
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // Live Completion Summary Bar
          if (summary != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.secondaryLightOrange.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Students: ${_matrixData?['total_students'] ?? 0}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                  ),
                  Text(
                    "Distributed: ${summary['total_distributed_items']} / ${summary['total_eligible_items']} (${summary['completion_rate']}%)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryOrange),
                  ),
                ],
              ),
            ),

          // Student Distribution Cards List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
                : rows.isEmpty
                    ? const Center(child: Text("No students found for this filter."))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final itemsMap = (row['items'] as Map<String, dynamic>?) ?? {};

                          Color statusColor = AppColors.statusPending;
                          if (row['status'] == 'COMPLETED') statusColor = AppColors.statusDistributed;
                          if (row['status'] == 'PARTIAL') statusColor = AppColors.statusPartial;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row['name'],
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                                        ),
                                        Text(
                                          "${row['student_uid']} • ${row['roll_number']} • Sem ${row['semester']}",
                                          style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "${row['total_received']} / ${row['total_eligible']} Received",
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                                      ),
                                    ),
                                  ],
                                ),
                                if (row['is_winner'] == true) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.emoji_events, size: 14, color: AppColors.primaryOrange),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Winner: ${row['winner_position']}",
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                                      ),
                                    ],
                                  ),
                                ],
                                const Divider(height: 20),

                                // Checkboxes for each item
                                ...itemsMap.entries.map((entry) {
                                  final invId = int.tryParse(entry.key) ?? 0;
                                  final itemData = entry.value as Map<String, dynamic>;
                                  final eligible = itemData['eligible'] == true;
                                  final received = itemData['received'] == true;
                                  final itemName = itemData['item_name'] ?? 'Item';
                                  final remaining = itemData['remaining_stock'] ?? 0;

                                  if (!eligible) {
                                    return const SizedBox.shrink();
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: received,
                                              activeColor: AppColors.statusDistributed,
                                              onChanged: received
                                                  ? null
                                                  : (val) {
                                                      if (val == true) {
                                                        _distributeItem(row['student_id'], invId, row['name'], itemName);
                                                      }
                                                    },
                                            ),
                                            Text(
                                              itemName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: received ? FontWeight.bold : FontWeight.normal,
                                                color: received ? AppColors.primaryNavy : AppColors.textGray,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (received)
                                          TextButton.icon(
                                            onPressed: () {
                                              if (itemData['distribution_id'] != null) {
                                                _undoDistribution(itemData['distribution_id'], row['name'], itemName);
                                              }
                                            },
                                            icon: const Icon(Icons.undo, size: 14, color: AppColors.statusOutOfStock),
                                            label: const Text("Undo", style: TextStyle(fontSize: 11, color: AppColors.statusOutOfStock)),
                                          )
                                        else
                                          Text(
                                            "$remaining available",
                                            style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
