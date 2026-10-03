class AdminUser {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role;

  AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? 'Admin',
      role: json['role'] ?? 'SUPER_ADMIN',
    );
  }
}

class AcademicSessionModel {
  final int id;
  final String sessionName;
  final String currentScheme;
  final bool isActive;
  final List<int> activeSemesters;

  AcademicSessionModel({
    required this.id,
    required this.sessionName,
    required this.currentScheme,
    required this.isActive,
    required this.activeSemesters,
  });

  factory AcademicSessionModel.fromJson(Map<String, dynamic> json) {
    return AcademicSessionModel(
      id: json['id'] ?? 0,
      sessionName: json['session_name'] ?? '',
      currentScheme: json['current_scheme'] ?? 'ODD',
      isActive: json['is_active'] ?? true,
      activeSemesters: (json['active_semesters'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [3, 5, 7],
    );
  }
}

class StudentModel {
  final int id;
  final String studentId;
  final String rollNumber;
  final String name;
  final String? email;
  final String? phone;
  final String branch;
  final String batch;
  final int currentSemester;
  final String status;

  StudentModel({
    required this.id,
    required this.studentId,
    required this.rollNumber,
    required this.name,
    this.email,
    this.phone,
    required this.branch,
    required this.batch,
    required this.currentSemester,
    required this.status,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? '',
      rollNumber: json['roll_number'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      branch: json['branch'] ?? 'CSE',
      batch: json['batch'] ?? '2025',
      currentSemester: json['current_semester'] ?? 3,
      status: json['status'] ?? 'ACTIVE',
    );
  }
}

class EventListItemModel {
  final int id;
  final String eventUid;
  final String name;
  final String eventType;
  final String eventDate;
  final String? eventTime;
  final String? venue;
  final String status;
  final String semesterScheme;
  final List<int> applicableSemesters;
  final int totalParticipants;
  final int totalInventoryItems;
  final int totalQuantity;
  final int distributedQuantity;
  final int remainingQuantity;
  final double distributionPercentage;

  EventListItemModel({
    required this.id,
    required this.eventUid,
    required this.name,
    required this.eventType,
    required this.eventDate,
    this.eventTime,
    this.venue,
    required this.status,
    required this.semesterScheme,
    required this.applicableSemesters,
    required this.totalParticipants,
    required this.totalInventoryItems,
    required this.totalQuantity,
    required this.distributedQuantity,
    required this.remainingQuantity,
    required this.distributionPercentage,
  });

  factory EventListItemModel.fromJson(Map<String, dynamic> json) {
    return EventListItemModel(
      id: json['id'] ?? 0,
      eventUid: json['event_uid'] ?? '',
      name: json['name'] ?? '',
      eventType: json['event_type'] ?? 'Event',
      eventDate: json['event_date'] ?? '',
      eventTime: json['event_time'],
      venue: json['venue'],
      status: json['status'] ?? 'Upcoming',
      semesterScheme: json['semester_scheme'] ?? 'ODD',
      applicableSemesters: (json['applicable_semesters'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [3, 5, 7],
      totalParticipants: json['total_participants'] ?? 0,
      totalInventoryItems: json['total_inventory_items'] ?? 0,
      totalQuantity: json['total_quantity'] ?? 0,
      distributedQuantity: json['distributed_quantity'] ?? 0,
      remainingQuantity: json['remaining_quantity'] ?? 0,
      distributionPercentage: (json['distribution_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EventInventoryModel {
  final int id;
  final int eventId;
  final int inventoryItemId;
  final String itemName;
  final String category;
  final String unit;
  final int initialQuantity;
  final int distributedQuantity;
  final int remainingQuantity;
  final String eligibilityType;
  final int? semesterFilter;
  final int lowStockThreshold;
  final String status;

  EventInventoryModel({
    required this.id,
    required this.eventId,
    required this.inventoryItemId,
    required this.itemName,
    required this.category,
    required this.unit,
    required this.initialQuantity,
    required this.distributedQuantity,
    required this.remainingQuantity,
    required this.eligibilityType,
    this.semesterFilter,
    required this.lowStockThreshold,
    required this.status,
  });

  factory EventInventoryModel.fromJson(Map<String, dynamic> json) {
    return EventInventoryModel(
      id: json['id'] ?? 0,
      eventId: json['event_id'] ?? 0,
      inventoryItemId: json['inventory_item_id'] ?? 0,
      itemName: json['item_name'] ?? 'Item',
      category: json['category'] ?? 'Other',
      unit: json['unit'] ?? 'units',
      initialQuantity: json['initial_quantity'] ?? 0,
      distributedQuantity: json['distributed_quantity'] ?? 0,
      remainingQuantity: json['remaining_quantity'] ?? 0,
      eligibilityType: json['eligibility_type'] ?? 'ALL',
      semesterFilter: json['semester_filter'],
      lowStockThreshold: json['low_stock_threshold'] ?? 10,
      status: json['status'] ?? 'Available',
    );
  }
}

class MasterInventoryModel {
  final int id;
  final String name;
  final String category;
  final String unit;
  final String? description;
  final int totalAllocated;
  final int totalDistributed;
  final int totalRemaining;
  final int eventsCount;

  MasterInventoryModel({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.description,
    required this.totalAllocated,
    required this.totalDistributed,
    required this.totalRemaining,
    required this.eventsCount,
  });

  factory MasterInventoryModel.fromJson(Map<String, dynamic> json) {
    return MasterInventoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      category: json['category'] ?? 'Other',
      unit: json['unit'] ?? 'units',
      description: json['description'],
      totalAllocated: json['total_allocated'] ?? 0,
      totalDistributed: json['total_distributed'] ?? 0,
      totalRemaining: json['total_remaining'] ?? 0,
      eventsCount: json['events_count'] ?? 0,
    );
  }
}

class DashboardOverviewModel {
  final String academicSessionName;
  final String currentScheme;
  final List<int> activeSemesters;
  final int activeStudentsCount;
  final int activeEventsCount;
  final int totalEventsCount;
  final int totalInventoryUnits;
  final int totalDistributedUnits;
  final int totalPendingUnits;
  final List<EventListItemModel> recentEvents;
  final List<Map<String, dynamic>> lowStockAlerts;
  final List<Map<String, dynamic>> recentDistributions;

  DashboardOverviewModel({
    required this.academicSessionName,
    required this.currentScheme,
    required this.activeSemesters,
    required this.activeStudentsCount,
    required this.activeEventsCount,
    required this.totalEventsCount,
    required this.totalInventoryUnits,
    required this.totalDistributedUnits,
    required this.totalPendingUnits,
    required this.recentEvents,
    required this.lowStockAlerts,
    required this.recentDistributions,
  });

  factory DashboardOverviewModel.fromJson(Map<String, dynamic> json) {
    return DashboardOverviewModel(
      academicSessionName: json['academic_session_name'] ?? '2026-27',
      currentScheme: json['current_scheme'] ?? 'ODD',
      activeSemesters: (json['active_semesters'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [3, 5, 7],
      activeStudentsCount: json['active_students_count'] ?? 0,
      activeEventsCount: json['active_events_count'] ?? 0,
      totalEventsCount: json['total_events_count'] ?? 0,
      totalInventoryUnits: json['total_inventory_units'] ?? 0,
      totalDistributedUnits: json['total_distributed_units'] ?? 0,
      totalPendingUnits: json['total_pending_units'] ?? 0,
      recentEvents: (json['recent_events'] as List<dynamic>?)?.map((e) => EventListItemModel.fromJson(e)).toList() ?? [],
      lowStockAlerts: (json['low_stock_alerts'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
      recentDistributions: (json['recent_distributions'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
    );
  }
}
