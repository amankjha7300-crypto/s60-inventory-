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
    List<dynamic> masterItems = [];
    try {
      masterItems = await _api.getMasterInventory();
    } catch (_) {
      masterItems = [];
    }
    if (!mounted) return;

    bool isCustom = masterItems.isEmpty;
    int? selectedMasterId = masterItems.isNotEmpty ? masterItems[0]['id'] : null;
    final customNameCtrl = TextEditingController();
    final customCategoryCtrl = TextEditingController(text: 'Apparel');
    final customUnitCtrl = TextEditingController(text: 'units');
    final qtyController = TextEditingController(text: '60');
    String eligibility = 'ALL';
    bool isSubmitting = false;

    final categories = ['Apparel', 'Stationery', 'Certificate', 'Award', 'Gift', 'Kit', 'Electronics', 'Prize', 'Other'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Add Event Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Poppins', color: AppColors.primaryNavy)),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(ctx),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mode Switcher: Catalog vs Custom
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (masterItems.isNotEmpty) {
                              setDialogState(() => isCustom = false);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !isCustom ? AppColors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: !isCustom
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                "From Catalog",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: !isCustom ? FontWeight.bold : FontWeight.w500,
                                  color: !isCustom ? AppColors.primaryNavy : AppColors.textGray,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => isCustom = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isCustom ? AppColors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isCustom
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                  : [],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: 14, color: isCustom ? AppColors.primaryOrange : AppColors.textGray),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Custom Item",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isCustom ? FontWeight.bold : FontWeight.w500,
                                      color: isCustom ? AppColors.primaryOrange : AppColors.textGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (!isCustom && masterItems.isNotEmpty) ...[
                  const Text('Select Catalog Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedMasterId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: masterItems.map<DropdownMenuItem<int>>((item) {
                      return DropdownMenuItem<int>(
                        value: item['id'],
                        child: Text(
                          "${item['name']} (${item['category']})",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedMasterId = val);
                    },
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: () => setDialogState(() => isCustom = true),
                      icon: const Icon(Icons.add_circle_outline, size: 14, color: AppColors.primaryOrange),
                      label: const Text("+ Create new custom item", style: TextStyle(fontSize: 11, color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else ...[
                  const Text('Item Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: customNameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Smart Watch, Custom Hoodie, Trophy',
                      hintStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: customCategoryCtrl.text,
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) {
                                if (val != null) customCategoryCtrl.text = val;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: customUnitCtrl,
                              decoration: InputDecoration(
                                hintText: 'units / pcs',
                                hintStyle: const TextStyle(fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quantity *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '60',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Eligibility Rule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: eligibility,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'ALL', child: Text('All Students', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'WINNERS', child: Text('Winners Only', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'SELECTED', child: Text('Selected', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => eligibility = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textGray)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                      if (qty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid quantity greater than 0')),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        int targetItemId;
                        if (isCustom) {
                          final name = customNameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter an item name')),
                            );
                            setDialogState(() => isSubmitting = false);
                            return;
                          }

                          // Check if item already exists in master catalog
                          final existing = masterItems.firstWhere(
                            (it) => it['name'].toString().toLowerCase() == name.toLowerCase(),
                            orElse: () => null,
                          );

                          if (existing != null) {
                            targetItemId = existing['id'];
                          } else {
                            // Create new master catalog item
                            final newItem = await _api.createMasterInventory({
                              'name': name,
                              'category': customCategoryCtrl.text.trim().isNotEmpty ? customCategoryCtrl.text.trim() : 'Other',
                              'unit': customUnitCtrl.text.trim().isNotEmpty ? customUnitCtrl.text.trim() : 'units',
                              'description': 'Created for event',
                            });
                            targetItemId = newItem['id'];
                          }
                        } else {
                          if (selectedMasterId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select an item from the catalog')),
                            );
                            setDialogState(() => isSubmitting = false);
                            return;
                          }
                          targetItemId = selectedMasterId!;
                        }

                        // Allocate to the event
                        await _api.addEventInventory(widget.eventId, {
                          'inventory_item_id': targetItemId,
                          'initial_quantity': qty,
                          'eligibility_type': eligibility,
                        });

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.statusDistributed,
                              content: Text('Item successfully added to event!'),
                            ),
                          );
                          _loadEvent();
                        }
                      } catch (e) {
                        if (mounted) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.statusOutOfStock,
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  ),
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
                  ),
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
                    ),
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
