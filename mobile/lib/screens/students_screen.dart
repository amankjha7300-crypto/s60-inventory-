import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import 'student_import_screen.dart';
import 'student_detail_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  int? _selectedSemester;
  String _status = 'ACTIVE';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    context.read<AppProvider>().loadStudents(
      search: _searchController.text.trim(),
      semester: _selectedSemester,
      status: _status,
    );
  }

  void _navigateToStudentDetail(int studentId, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(
          studentId: studentId,
          studentName: name,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _showAddStudentDialog() {
    final sidCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final batchCtrl = TextEditingController(text: '2025');
    int sem = _selectedSemester ?? 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1, color: AppColors.primaryOrange, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Enlist New Student',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryNavy),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Single source of student records. Historical reward records stay preserved across semester promotions.",
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sidCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Super60 Student ID *',
                    hintText: 'e.g. S60-181',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rollCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'University Roll Number *',
                    hintText: 'e.g. 24CSE181',
                    prefixIcon: Icon(Icons.format_list_numbered, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Student Full Name *',
                    hintText: 'e.g. Yash Sharma',
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: sem,
                  decoration: const InputDecoration(
                    labelText: 'Semester Level & Scheme *',
                    prefixIcon: Icon(Icons.school_outlined, size: 18),
                  ),
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
                const SizedBox(height: 12),
                TextField(
                  controller: batchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Batch',
                    hintText: 'e.g. 2025',
                    prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'e.g. yash@sviet.ac.in',
                    prefixIcon: Icon(Icons.mail_outline, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. +91 9876543210',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textGray)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Enlist Student'),
              onPressed: () async {
                final sid = sidCtrl.text.trim();
                final roll = rollCtrl.text.trim();
                final name = nameCtrl.text.trim();

                if (sid.isEmpty || roll.isEmpty || name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields: ID, Roll, and Name.')),
                  );
                  return;
                }

                try {
                  await _api.createStudent({
                    'student_id': sid,
                    'roll_number': roll,
                    'name': name,
                    'email': emailCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'batch': batchCtrl.text.trim(),
                    'branch': 'CSE',
                    'current_semester': sem,
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Student '$name' enlisted successfully!")),
                    );
                    _loadData();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final students = provider.students;
    final currentScheme = provider.currentSession?.currentScheme ?? 'ODD';
    final activeSemesters = currentScheme == 'ODD' ? [3, 5, 7] : [4, 6, 8];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Student Records",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: AppColors.primaryOrange),
            tooltip: "Bulk Import",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentImportScreen()),
              ).then((_) => _loadData());
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: _showAddStudentDialog,
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: const Text("Enlist Student", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.person_add_alt_1, color: AppColors.white),
        label: const Text(
          "Enlist Student",
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _loadData(),
                  decoration: const InputDecoration(
                    hintText: 'Search by student name, S60 ID, or roll...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Semesters'),
                        selected: _selectedSemester == null,
                        onSelected: (_) {
                          setState(() => _selectedSemester = null);
                          _loadData();
                        },
                      ),
                      ...activeSemesters.map((sem) => Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: FilterChip(
                              label: Text('$sem' 'th Sem'),
                              selected: _selectedSemester == sem,
                              onSelected: (_) {
                                setState(() => _selectedSemester = sem);
                                _loadData();
                              },
                            ),
                          )),
                      const SizedBox(width: 8),
                      // Status filter
                      FilterChip(
                        label: Text(_status == 'ACTIVE' ? 'Active' : 'All Status'),
                        selected: _status == 'ALL',
                        onSelected: (_) {
                          setState(() {
                            _status = (_status == 'ACTIVE') ? 'ALL' : 'ACTIVE';
                          });
                          _loadData();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Students List or Empty State
          Expanded(
            child: students.isEmpty
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
                            child: const Icon(Icons.school_outlined, size: 48, color: AppColors.primaryOrange),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No Student Records",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Student list is completely clean with zero predefined data. Tap below to enlist students.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textGray),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _showAddStudentDialog,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text("Enlist First Student"),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80), // extra bottom padding for FAB
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final st = students[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _navigateToStudentDetail(st.id, st.name),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Avatar Initials
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryNavy.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        st.name.isNotEmpty ? st.name[0].toUpperCase() : 'S',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: AppColors.primaryNavy,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          st.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryNavy,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryOrange.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                st.studentId,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primaryOrange,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              st.rollNumber,
                                              style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "• ${st.currentSemester}th Sem",
                                              style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Action indicator
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightSurface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Record",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryNavy,
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(Icons.chevron_right, size: 14, color: AppColors.primaryNavy),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
