import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/app_provider.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  const DashboardScreen({super.key, this.onTabChange});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshSessionAndDashboard();
    });
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGray, fontFamily: 'Poppins'),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color, fontFamily: 'Poppins'),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: AppColors.textGray.withOpacity(0.8), fontFamily: 'Poppins'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final dash = provider.dashboard;
    final admin = provider.currentAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/s60_symbol.png',
              height: 28,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, color: AppColors.primaryOrange),
            ),
            const SizedBox(width: 8),
            const Text(
              "S60 Inventory",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.primaryNavy),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, size: 14, color: AppColors.primaryOrange),
                const SizedBox(width: 4),
                Text(
                  "${dash?.academicSessionName ?? '2026-27'} • ${dash?.currentScheme ?? 'ODD'}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refreshSessionAndDashboard(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Text(
                "Good morning, ${admin?.fullName ?? 'Admin'}",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 4),
              Text(
                "Active Semesters: ${dash?.activeSemesters.map((s) => '${s}th').join(', ') ?? '3rd, 5th, 7th'}",
                style: const TextStyle(fontSize: 13, color: AppColors.textGray, fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 20),

              // 4 Core Metric Cards Grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  _buildStatCard(
                    title: "Active Students",
                    value: "${dash?.activeStudentsCount ?? 180}",
                    icon: Icons.people_outline,
                    color: AppColors.primaryNavy,
                    subtitle: "Across ${dash?.activeSemesters.length ?? 3} active batches",
                    onTap: () => widget.onTabChange?.call(1),
                  ),
                  _buildStatCard(
                    title: "Saved Events",
                    value: "${dash?.totalEventsCount ?? 4}",
                    icon: Icons.event_note,
                    color: AppColors.primaryOrange,
                    subtitle: "${dash?.activeEventsCount ?? 2} active/ongoing",
                    onTap: () => widget.onTabChange?.call(2),
                  ),
                  _buildStatCard(
                    title: "Distributed Items",
                    value: "${dash?.totalDistributedUnits ?? 710}",
                    icon: Icons.check_circle_outline,
                    color: AppColors.statusDistributed,
                    subtitle: "${dash?.totalPendingUnits ?? 140} pending units",
                    onTap: () => widget.onTabChange?.call(3),
                  ),
                  _buildStatCard(
                    title: "Total Inventory",
                    value: "${dash?.totalInventoryUnits ?? 850}+",
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.statusPartial,
                    subtitle: "Units across all events",
                    onTap: () => widget.onTabChange?.call(4),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                "Quick Actions",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.onTabChange?.call(1); // Jump to Students tab
                      },
                      icon: const Icon(Icons.person_add_alt_1, size: 16, color: AppColors.primaryOrange),
                      label: const Text("Enlist Student", style: TextStyle(color: AppColors.primaryNavy, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryOrange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CreateEventScreen()),
                        ).then((_) => provider.refreshSessionAndDashboard());
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.primaryNavy),
                      label: const Text("New Event", style: TextStyle(color: AppColors.primaryNavy, fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.onTabChange?.call(3); // Navigate to Distribution Tab
                      },
                      icon: const Icon(Icons.playlist_add_check, size: 16, color: AppColors.statusDistributed),
                      label: const Text("Distribute", style: TextStyle(color: AppColors.primaryNavy, fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Low Stock Alerts (if any)
              if (dash != null && dash.lowStockAlerts.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.statusPending, size: 20),
                    const SizedBox(width: 6),
                    const Text(
                      "Inventory Stock Alerts",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Poppins'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...dash.lowStockAlerts.map((alert) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: alert['remaining'] == 0 ? AppColors.statusOutOfStock.withOpacity(0.08) : AppColors.statusPending.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: alert['remaining'] == 0 ? AppColors.statusOutOfStock.withOpacity(0.3) : AppColors.statusPending.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        alert['remaining'] == 0 ? Icons.error_outline : Icons.info_outline,
                        color: alert['remaining'] == 0 ? AppColors.statusOutOfStock : AppColors.statusPending,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${alert['item_name']} in ${alert['event_name']}: ${alert['remaining']} units remaining (${alert['status']})",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primaryNavy),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
              ],

              // Recent Events Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Events",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Poppins'),
                  ),
                  TextButton(
                    onPressed: () => widget.onTabChange?.call(1),
                    child: const Text("View All ->", style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (dash != null && dash.recentEvents.isNotEmpty)
                ...dash.recentEvents.map((ev) => InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EventDetailScreen(eventId: ev.id)),
                    );
                  },
                  child: Container(
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
                              ev.eventUid,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ev.status == 'Active'
                                    ? AppColors.primaryOrange.withOpacity(0.12)
                                    : (ev.status == 'Completed' ? AppColors.statusDistributed.withOpacity(0.12) : AppColors.statusPartial.withOpacity(0.12)),
                                borderRadius: BorderRadius.circular(8),
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
                        const SizedBox(height: 6),
                        Text(
                          ev.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, fontFamily: 'Poppins'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${ev.eventDate} • ${ev.eventType}",
                          style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ev.totalQuantity > 0 ? (ev.distributedQuantity / ev.totalQuantity) : 0,
                            backgroundColor: AppColors.lightSurface,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${ev.distributedQuantity} / ${ev.totalQuantity} items distributed",
                              style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                            ),
                            Text(
                              "${ev.distributionPercentage}%",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }
}
