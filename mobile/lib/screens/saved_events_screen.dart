import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/app_provider.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';

class SavedEventsScreen extends StatefulWidget {
  const SavedEventsScreen({super.key});

  @override
  State<SavedEventsScreen> createState() => _SavedEventsScreenState();
}

class _SavedEventsScreenState extends State<SavedEventsScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'ALL';
  String _selectedScheme = 'ALL';
  int? _selectedSemester;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    context.read<AppProvider>().loadEvents(
      search: _searchController.text.trim(),
      status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      scheme: _selectedScheme == 'ALL' ? null : _selectedScheme,
      semester: _selectedSemester,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primaryOrange.withOpacity(0.15),
        checkmarkColor: AppColors.primaryOrange,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primaryOrange : AppColors.textGray,
          fontFamily: 'Poppins',
        ),
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? AppColors.primaryOrange : AppColors.borderSubtle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final events = provider.events;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          "Saved Events",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryNavy),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryNavy),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateEventScreen()),
          ).then((_) => _loadData());
        },
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text("Create Event", style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _loadData(),
                  decoration: InputDecoration(
                    hintText: 'Search by event name, ID, or venue...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textGray),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadData();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.lightSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip("All Status", _selectedStatus == 'ALL', () {
                        setState(() => _selectedStatus = 'ALL');
                        _loadData();
                      }),
                      _buildFilterChip("Active", _selectedStatus == 'Active', () {
                        setState(() => _selectedStatus = 'Active');
                        _loadData();
                      }),
                      _buildFilterChip("Upcoming", _selectedStatus == 'Upcoming', () {
                        setState(() => _selectedStatus = 'Upcoming');
                        _loadData();
                      }),
                      _buildFilterChip("Completed", _selectedStatus == 'Completed', () {
                        setState(() => _selectedStatus = 'Completed');
                        _loadData();
                      }),
                      _buildFilterChip("Archived", _selectedStatus == 'Archived', () {
                        setState(() => _selectedStatus = 'Archived');
                        _loadData();
                      }),
                      Container(width: 1, height: 24, color: AppColors.borderSubtle, margin: const EdgeInsets.symmetric(horizontal: 6)),
                      _buildFilterChip("ODD Scheme", _selectedScheme == 'ODD', () {
                        setState(() => _selectedScheme = _selectedScheme == 'ODD' ? 'ALL' : 'ODD');
                        _loadData();
                      }),
                      _buildFilterChip("EVEN Scheme", _selectedScheme == 'EVEN', () {
                        setState(() => _selectedScheme = _selectedScheme == 'EVEN' ? 'ALL' : 'EVEN');
                        _loadData();
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Events List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
                : events.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryLightOrange.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.event_busy, size: 48, color: AppColors.primaryOrange),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No events found",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Create your first event to start tracking inventory and rewards.",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppColors.textGray),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadData(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            final ev = events[index];
                            final progress = ev.totalQuantity > 0 ? (ev.distributedQuantity / ev.totalQuantity) : 0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderSubtle),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => EventDetailScreen(eventId: ev.id)),
                                  ).then((_) => _loadData());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top row: UID + Status badge
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryOrange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              ev.eventUid,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryOrange,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: ev.status == 'Active'
                                                  ? AppColors.primaryOrange.withOpacity(0.12)
                                                  : (ev.status == 'Completed' ? AppColors.statusDistributed.withOpacity(0.12) : AppColors.statusPartial.withOpacity(0.12)),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              ev.status,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: ev.status == 'Active'
                                                    ? AppColors.primaryOrange
                                                    : (ev.status == 'Completed' ? AppColors.statusDistributed : AppColors.statusPartial),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Event Title
                                      Text(
                                        ev.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryNavy,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // Event Subtitle info
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 13, color: AppColors.textGray),
                                          const SizedBox(width: 4),
                                          Text(
                                            ev.eventDate,
                                            style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.layers_outlined, size: 14, color: AppColors.textGray),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${ev.semesterScheme} Sem • ${ev.applicableSemesters.map((s) => '${s}th').join(', ')} Sem",
                                            style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Distribution progress & item summary
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "${ev.totalInventoryItems} Item Types",
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
                                          ),
                                          Text(
                                            "Distribution: ${ev.distributedQuantity} / ${ev.totalQuantity} items",
                                            style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: AppColors.lightSurface,
                                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                                          minHeight: 6,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Action row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            "View Event ->",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryOrange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
