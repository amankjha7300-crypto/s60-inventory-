import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService _api = ApiService();
  String _reportType = 'distribution';
  bool _isLoading = true;
  List<dynamic> _reportData = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getEvents(); // default list
      setState(() {
        _reportData = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _exportCsv() {
    final exportUrl = "${_api.baseUrl}/reports/export-csv?report_type=$_reportType";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export CSV Report', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Download complete Excel/CSV report file directly from backend:'),
            const SizedBox(height: 12),
            SelectableText(
              exportUrl,
              style: const TextStyle(fontSize: 12, color: AppColors.primaryOrange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Management Reports", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: AppColors.primaryOrange),
            tooltip: "Export CSV",
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report type selection chips
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Event Reports'),
                  selected: _reportType == 'events',
                  selectedColor: AppColors.primaryOrange.withOpacity(0.15),
                  onSelected: (_) {
                    setState(() => _reportType = 'events');
                    _loadReport();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Distribution Logs'),
                  selected: _reportType == 'distribution',
                  selectedColor: AppColors.primaryOrange.withOpacity(0.15),
                  onSelected: (_) {
                    setState(() => _reportType = 'distribution');
                    _loadReport();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Export banner
            Container(
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
                      color: AppColors.statusDistributed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_chart_outlined, color: AppColors.statusDistributed),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Export To Excel / CSV", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryNavy)),
                        Text("Download full event distribution and inventory records.", style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _exportCsv,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      minimumSize: const Size(60, 36),
                    ),
                    child: const Text("Export", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              "Report Overview",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 10),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
                : Column(
                    children: _reportData.map((ev) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ev['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryNavy)),
                              Text("${ev['event_date']} • ${ev['event_type']}", style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                            ],
                          ),
                          Text(
                            "${ev['distributed_quantity']} / ${ev['total_quantity']} Items",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryOrange),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}
