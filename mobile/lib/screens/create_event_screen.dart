import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/api_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _dateController = TextEditingController(text: '15 Oct 2026');
  final _timeController = TextEditingController(text: '10:00 AM');
  final _venueController = TextEditingController(text: 'SVIET Seminar Hall');

  String _eventType = 'Workshop';
  String _scheme = 'ODD';
  final List<int> _selectedSemesters = [3, 5, 7];
  bool _isSaving = false;

  final List<String> _eventTypes = [
    'Workshop',
    'Seminar',
    'Competition',
    'Hackathon',
    'Training',
    'Industry Visit',
    'Recognition',
    'Orientation',
    'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  void _onSchemeChanged(String? newScheme) {
    if (newScheme == null) return;
    setState(() {
      _scheme = newScheme;
      _selectedSemesters.clear();
      if (_scheme == 'ODD') {
        _selectedSemesters.addAll([3, 5, 7]);
      } else {
        _selectedSemesters.addAll([4, 6, 8]);
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSemesters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one applicable semester.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final res = await ApiService().createEvent({
        'name': _nameController.text.trim(),
        'event_type': _eventType,
        'description': _descController.text.trim(),
        'event_date': _dateController.text.trim(),
        'event_time': _timeController.text.trim(),
        'venue': _venueController.text.trim(),
        'semester_scheme': _scheme,
        'applicable_semesters': _selectedSemesters,
        'status': 'Upcoming',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusDistributed,
            content: Text("Event '${res['name']}' (${res['event_uid']}) created successfully!"),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.statusOutOfStock, content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSemesters = _scheme == 'ODD' ? [3, 5, 7] : [4, 6, 8];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create New Event', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Event Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(hintText: 'e.g. Full Stack Cloud & DevOps Hackathon'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Event name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    const Text('Event Type *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _eventType,
                      items: _eventTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _eventType = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _dateController,
                                decoration: const InputDecoration(hintText: '15 Oct 2026'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Date required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _timeController,
                                decoration: const InputDecoration(hintText: '10:00 AM'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Venue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _venueController,
                      decoration: const InputDecoration(hintText: 'e.g. Lab 301, SVIET Campus'),
                    ),
                    const SizedBox(height: 16),

                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Add brief event details and learning outcomes...'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Academic Session & Semester Applicability
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Academic Scheme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('ODD Scheme (3rd, 5th, 7th)'),
                          selected: _scheme == 'ODD',
                          selectedColor: AppColors.primaryOrange.withOpacity(0.15),
                          onSelected: (_) => _onSchemeChanged('ODD'),
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text('EVEN Scheme (4th, 6th, 8th)'),
                          selected: _scheme == 'EVEN',
                          selectedColor: AppColors.primaryOrange.withOpacity(0.15),
                          onSelected: (_) => _onSchemeChanged('EVEN'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Applicable Semesters *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: availableSemesters.map((sem) {
                        final isSelected = _selectedSemesters.contains(sem);
                        return FilterChip(
                          label: Text('${sem}th Semester'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSemesters.add(sem);
                              } else {
                                _selectedSemesters.remove(sem);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('Save Event Permanently', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
