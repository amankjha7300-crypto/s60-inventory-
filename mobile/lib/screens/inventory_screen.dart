import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    context.read<AppProvider>().loadMasterInventory(
      search: _searchController.text.trim(),
      category: _selectedCategory == 'ALL' ? null : _selectedCategory,
    );
  }

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Apparel');
    final unitCtrl = TextEditingController(text: 'units');
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Master Catalog Item', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name *', hintText: 'e.g. Wireless Mouse')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: 'Apparel',
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'Apparel', child: Text('Apparel')),
                  DropdownMenuItem(value: 'Stationery', child: Text('Stationery')),
                  DropdownMenuItem(value: 'Certificate', child: Text('Certificate')),
                  DropdownMenuItem(value: 'Award', child: Text('Award')),
                  DropdownMenuItem(value: 'Gift', child: Text('Gift')),
                  DropdownMenuItem(value: 'Kit', child: Text('Kit')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) catCtrl.text = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit', hintText: 'units / pieces')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                await ApiService().createMasterInventory({
                  'name': nameCtrl.text.trim(),
                  'category': catCtrl.text.trim(),
                  'unit': unitCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final inventory = provider.masterInventory;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Master Inventory", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primaryOrange),
            tooltip: "Add Item",
            onPressed: _showAddItemDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _loadData(),
              decoration: const InputDecoration(
                hintText: 'Search items (e.g. T-Shirt, Notebook, Trophy)...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: inventory.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.primaryOrange),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Master Inventory is Clean",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "No predefined items or rewards exist. Add custom items to your catalog.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textGray),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _showAddItemDialog,
                            icon: const Icon(Icons.add),
                            label: const Text("Add First Item"),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: inventory.length,
                    itemBuilder: (context, index) {
                final item = inventory[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2, color: AppColors.primaryOrange),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                            ),
                            Text(
                              "${item.category} • ${item.eventsCount} Events Associated",
                              style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text("Allocated: ${item.totalAllocated}  ", style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
                                Text("Distributed: ${item.totalDistributed}  ", style: const TextStyle(fontSize: 11, color: AppColors.statusDistributed, fontWeight: FontWeight.w600)),
                                Text("Remaining: ${item.totalRemaining}", style: const TextStyle(fontSize: 11, color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
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
          ),
        ],
      ),
    );
  }
}
