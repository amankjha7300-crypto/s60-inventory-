import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/api_service.dart';
import 'distribution_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  Map<String, dynamic>? _event;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getEventDetail(widget.eventId);
      setState(() {
        _event = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showAddInventoryDialog() async {
    final masterItems = await _api.getMasterInventory();
    if (!mounted || masterItems.isEmpty) return;

    int selectedMasterId = masterItems[0]['id'];
    final qtyController = TextEditingController(text: '60');
    String eligibility = 'ALL';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Event Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Item Catalog', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: selectedMasterId,
                  items: masterItems.map<DropdownMenuItem<int>>((item) {
                    return DropdownMenuItem<int>(
                      value: item['id'],
                      child: Text("${item['name']} (${item['category']})"),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedMasterId = val);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '60'),
                ),
                const SizedBox(height: 16),
                const Text('Eligibility Rule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: eligibility,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Eligible Students')),
                    DropdownMenuItem(value: 'WINNERS', child: Text('Winners Only')),
                    DropdownMenuItem(value: 'SELECTED', child: Text('Selected Students')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => eligibility = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyController.text) ?? 0;
                if (qty <= 0) return;
                try {
                  await _api.addEventInventory(widget.eventId, {
                    'inventory_item_id': selectedMasterId,
                    'initial_quantity': qty,
                    'eligibility_type': eligibility,
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadEvent();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
      );
    }

    if (_error != null || _event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Event not found'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadEvent, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final ev = _event!;
    final inventories = (ev['inventories'] as List<dynamic>?) ?? [];
    final winners = (ev['winners'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text(
          ev['event_uid'] ?? 'Event',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvent,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.textGray,
          indicatorColor: AppColors.primaryOrange,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
          tabs: const [
            Tab(text: "Inventory / Rewards"),
            Tab(text: "Overview"),
            Tab(text: "Winners"),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DistributionScreen(initialEventId: widget.eventId)),
            ).then((_) => _loadEvent());
          },
          icon: const Icon(Icons.playlist_add_check, color: AppColors.white),
          label: const Text(
            "Open Distribution Portal",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Inventory & Rewards Table
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Allocated Rewards (${inventories.length})",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Poppins'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showAddInventoryDialog,
                      icon: const Icon(Icons.add, size: 16, color: AppColors.primaryOrange),
                      label: const Text("Add Item", style: TextStyle(color: AppColors.primaryNavy, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ...inventories.map((inv) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            inv['item_name'],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: inv['status'] == 'Available'
                                  ? AppColors.statusDistributed.withOpacity(0.12)
                                  : (inv['status'] == 'Low Stock' ? AppColors.statusPending.withOpacity(0.12) : AppColors.statusOutOfStock.withOpacity(0.12)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              inv['status'],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: inv['status'] == 'Available'
                                    ? AppColors.statusDistributed
                                    : (inv['status'] == 'Low Stock' ? AppColors.statusPending : AppColors.statusOutOfStock),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Category: ${inv['category']} • Rule: ${inv['eligibility_type']}",
                        style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat("Total Added", "${inv['initial_quantity']}"),
                          _buildMiniStat("Distributed", "${inv['distributed_quantity']}"),
                          _buildMiniStat("Remaining", "${inv['remaining_quantity']}", isBold: true),
                        ],
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),

          // Tab 2: Overview & Description
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ev['name'],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ev['description'] ?? 'No description provided.',
                        style: const TextStyle(fontSize: 13, color: AppColors.textGray, height: 1.4),
                      ),
                      const Divider(height: 24),
                      _buildDetailRow(Icons.calendar_today, "Event Date", ev['event_date']),
                      _buildDetailRow(Icons.access_time, "Time", ev['event_time'] ?? 'Not specified'),
                      _buildDetailRow(Icons.location_on_outlined, "Venue", ev['venue'] ?? 'SVIET Campus'),
                      _buildDetailRow(Icons.school_outlined, "Semester Scheme", "${ev['semester_scheme']} Scheme"),
                      _buildDetailRow(Icons.people_outline, "Eligible Semesters", (ev['applicable_semesters'] as List<dynamic>).map((s) => '${s}th').join(', ')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab 3: Winners
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Event Winners (${winners.length})",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
                const SizedBox(height: 12),
                if (winners.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text("No winners declared yet for this event.", style: TextStyle(color: AppColors.textGray)),
                    ),
                  )
                else
                  ...winners.map((w) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                    ],
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryLightOrange.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emoji_events, color: AppColors.primaryOrange),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w['student_name'],
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                              ),
                              Text(
                                "${w['student_uid']} • ${w['position']}",
                                style: const TextStyle(fontSize: 12, color: AppColors.primaryOrange, fontWeight: FontWeight.w600),
                              ),
                              if (w['prize_title'] != null)
                                Text(
                                  w['prize_title'],
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
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, {bool isBold = false}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: AppColors.primaryNavy)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryOrange),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryNavy)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textGray))),
        ],
      ),
    );
  }
}
