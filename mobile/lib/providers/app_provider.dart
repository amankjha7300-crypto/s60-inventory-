import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AppProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  AdminUser? _currentAdmin;
  AcademicSessionModel? _currentSession;
  DashboardOverviewModel? _dashboard;
  List<EventListItemModel> _events = [];
  List<MasterInventoryModel> _masterInventory = [];
  List<StudentModel> _students = [];

  bool _isLoading = false;
  String? _errorMessage;

  AdminUser? get currentAdmin => _currentAdmin;
  AcademicSessionModel? get currentSession => _currentSession;
  DashboardOverviewModel? get dashboard => _dashboard;
  List<EventListItemModel> get events => _events;
  List<MasterInventoryModel> get masterInventory => _masterInventory;
  List<StudentModel> get students => _students;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentAdmin != null;

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void setError(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  Future<void> init() async {
    await _api.init();
    if (_api.isAuthenticated) {
      try {
        await refreshSessionAndDashboard();
      } catch (e) {
        await _api.logout();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    setLoading(true);
    setError(null);
    try {
      final res = await _api.login(email, password);
      _currentAdmin = AdminUser.fromJson(res['admin']);
      await refreshSessionAndDashboard();
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      setError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> signUp(Map<String, dynamic> payload) async {
    setLoading(true);
    setError(null);
    try {
      final res = await _api.signUp(payload);
      _currentAdmin = AdminUser.fromJson(res['admin']);
      await refreshSessionAndDashboard();
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      setError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _currentAdmin = null;
    _dashboard = null;
    _events = [];
    notifyListeners();
  }

  Future<void> refreshSessionAndDashboard() async {
    try {
      final sessData = await _api.getCurrentSession();
      _currentSession = AcademicSessionModel.fromJson(sessData);
      
      final dashData = await _api.getDashboard();
      _dashboard = DashboardOverviewModel.fromJson(dashData);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    }
  }

  Future<void> loadEvents({String? search, String? status, String? scheme, int? semester}) async {
    setLoading(true);
    try {
      final list = await _api.getEvents(search: search, status: status, scheme: scheme, semester: semester);
      _events = list.map((e) => EventListItemModel.fromJson(e)).toList();
      setLoading(false);
    } catch (e) {
      setLoading(false);
      setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> loadMasterInventory({String? search, String? category}) async {
    try {
      final list = await _api.getMasterInventory(search: search, category: category);
      _masterInventory = list.map((e) => MasterInventoryModel.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading inventory: $e');
    }
  }

  Future<void> loadStudents({String? search, int? semester, String status = 'ACTIVE'}) async {
    try {
      final data = await _api.getStudents(search: search, semester: semester, status: status);
      final items = data['items'] as List<dynamic>;
      _students = items.map((e) => StudentModel.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading students: $e');
    }
  }
}
