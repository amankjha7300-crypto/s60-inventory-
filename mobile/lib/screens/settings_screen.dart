import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import 'students_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showPromotionDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final session = provider.currentSession;
    if (session == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
    );

    try {
      final preview = await ApiService().previewPromotion(session.id);
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      final transitions = preview['transitions'] as Map<String, dynamic>;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Promote Students to Next Semester?', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Transitioning academic scheme from ${preview['scheme_from']} to ${preview['scheme_to']}:",
                style: const TextStyle(fontSize: 13, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 12),
              ...transitions.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                    Text("${e.value} students", style: const TextStyle(fontSize: 12, color: AppColors.primaryOrange)),
                  ],
                ),
              )),
              const Divider(height: 20),
              const Text(
                "Important: Student IDs and all historical reward records remain permanently intact.",
                style: TextStyle(fontSize: 11, color: AppColors.textGray, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await ApiService().executePromotion(session.id);
                await provider.refreshSessionAndDashboard();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppColors.statusDistributed, content: Text(res['message'] ?? 'Promotion successful!')),
                  );
                }
              },
              child: const Text('Confirm Promotion'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final session = provider.currentSession;
    final admin = provider.currentAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Management & Settings", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Profile Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primaryOrange.withOpacity(0.12),
                    child: const Icon(Icons.person, color: AppColors.primaryOrange, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          admin?.fullName ?? "Administrator",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
                        ),
                        Text(
                          admin?.email ?? "admin@s60sviet.in",
                          style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Role: ${admin?.role ?? 'SUPER_ADMIN'}",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryOrange),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Academic Scheme Card
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
                  const Text("Academic Session & Scheme", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryNavy)),
                  const SizedBox(height: 8),
                  Text("Session: ${session?.sessionName ?? '2026-27'}", style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
                  Text(
                    "Current Scheme: ${session?.currentScheme ?? 'ODD'} (${session?.activeSemesters.map((s) => '${s}th').join(', ') ?? '3rd, 5th, 7th'} Semesters Active)",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => _showPromotionDialog(context),
                    icon: const Icon(Icons.trending_up, color: AppColors.primaryOrange),
                    label: const Text("Promote Students to Next Scheme", style: TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryOrange),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Management Navigation
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.people_outline, color: AppColors.primaryNavy),
                    title: const Text("Student Records Database", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentsScreen()));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryNavy),
                    title: const Text("Master Inventory Items", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryScreen()));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bar_chart_outlined, color: AppColors.primaryNavy),
                    title: const Text("Reports & Analytics", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // About SVIET CSE S60
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
                  const Text("About S60 Management Portal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryNavy)),
                  const SizedBox(height: 6),
                  const Text(
                    "Super60 (S60) is the premier flagship industry-readiness and technical excellence initiative of the Department of Computer Science & Engineering, Swami Vivekanand Group of Institutes (SVIET).",
                    style: TextStyle(fontSize: 12, color: AppColors.textGray, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  const Text("Version 1.0.0 (Release Build)", style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            ElevatedButton.icon(
              onPressed: () async {
                await provider.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text("Sign Out"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusOutOfStock,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
