import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = AppConstants.defaultApiBaseUrl;
  String? _token;

  String get baseUrl => _baseUrl;
  bool get isAuthenticated => _token != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _baseUrl = prefs.getString('api_base_url') ?? AppConstants.defaultApiBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', _baseUrl);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // --- Auth APIs ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final token = data['data']['access_token'];
      await setToken(token);
      return data['data'];
    } else {
      throw Exception(data['detail'] ?? data['message'] ?? 'Login failed. Please check credentials.');
    }
  }

  Future<Map<String, dynamic>> signUp(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final token = data['data']['access_token'];
      await setToken(token);
      return data['data'];
    } else {
      throw Exception(data['detail'] ?? data['message'] ?? 'Sign up failed.');
    }
  }

  Future<void> logout() async {
    await setToken(null);
  }

  // --- Dashboard API ---
  Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(Uri.parse('$_baseUrl/dashboard'), headers: _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['detail'] ?? 'Failed to load dashboard metrics.');
  }

  // --- Academic Sessions & Promotion ---
  Future<Map<String, dynamic>> getCurrentSession() async {
    final response = await http.get(Uri.parse('$_baseUrl/academic-sessions/current'), headers: _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to fetch academic session.');
  }

  Future<Map<String, dynamic>> previewPromotion(int sessionId) async {
    final response = await http.get(Uri.parse('$_baseUrl/academic-sessions/$sessionId/promote-preview'), headers: _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to preview promotion.');
  }

  Future<Map<String, dynamic>> executePromotion(int sessionId) async {
    final response = await http.post(Uri.parse('$_baseUrl/academic-sessions/$sessionId/promote'), headers: _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Promotion failed.');
  }

  // --- Saved Events APIs ---
  Future<List<dynamic>> getEvents({String? search, String? status, String? scheme, int? semester}) async {
    var uri = Uri.parse('$_baseUrl/events').replace(queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status != 'ALL') 'status': status,
      if (scheme != null && scheme != 'ALL') 'scheme': scheme,
      if (semester != null) 'semester': semester.toString(),
    });
    final response = await http.get(uri, headers: _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data']['items'];
    throw Exception(data['detail'] ?? 'Failed to load events.');
  }

  Future<Map<String, dynamic>> getEventDetail(int eventId) async {
    final response = await http.get(Uri.parse('$_baseUrl/events/$eventId'), headers: _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to load event details.');
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> eventData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/events'),
      headers: _headers(),
      body: jsonEncode(eventData),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to create event.');
  }

  Future<void> archiveEvent(int eventId) async {
    final response = await http.post(Uri.parse('$_baseUrl/events/$eventId/archive'), headers: _headers());
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to archive event.');
    }
  }

  Future<Map<String, dynamic>> addEventInventory(int eventId, Map<String, dynamic> invData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/events/$eventId/inventory'),
      headers: _headers(),
      body: jsonEncode(invData),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to add inventory to event.');
  }

  Future<void> addEventWinner(int eventId, Map<String, dynamic> winnerData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/events/$eventId/winners'),
      headers: _headers(),
      body: jsonEncode(winnerData),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to add winner.');
    }
  }

  // --- Rewards & Distribution APIs ---
  Future<Map<String, dynamic>> getEventDistributionMatrix(int eventId, {int? semester, String? search, String? statusFilter}) async {
    var uri = Uri.parse('$_baseUrl/distribution/event/$eventId/matrix').replace(queryParameters: {
      if (semester != null) 'semester': semester.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (statusFilter != null && statusFilter != 'ALL') 'status_filter': statusFilter,
    });
    final response = await http.get(uri, headers: _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to load distribution matrix.');
  }

  Future<Map<String, dynamic>> saveDistribution(int studentId, int eventInventoryId, {int quantity = 1, String? remarks}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/distribution/save'),
      headers: _headers(),
      body: jsonEncode({
        'student_id': studentId,
        'event_inventory_id': eventInventoryId,
        'quantity': quantity,
        'remarks': remarks,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to save distribution.');
  }

  Future<void> reverseDistribution(int distributionId) async {
    final response = await http.post(Uri.parse('$_baseUrl/distribution/$distributionId/reverse'), headers: _headers());
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to reverse distribution.');
    }
  }

  // --- Student APIs ---
  Future<Map<String, dynamic>> getStudents({String? search, int? semester, String status = 'ACTIVE', int page = 1}) async {
    var uri = Uri.parse('$_baseUrl/students').replace(queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (semester != null) 'semester': semester.toString(),
      'status': status,
      'page': page.toString(),
      'page_size': '100',
    });
    final response = await http.get(uri, headers: _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to load students.');
  }

  Future<Map<String, dynamic>> getStudentProfile(int studentId) async {
    final response = await http.get(Uri.parse('$_baseUrl/students/$studentId'), headers: _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to load student profile.');
  }

  Future<void> deactivateStudent(int studentId) async {
    final response = await http.post(Uri.parse('$_baseUrl/students/$studentId/deactivate'), headers: _headers());
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to deactivate student.');
    }
  }

  Future<void> activateStudent(int studentId) async {
    final response = await http.post(Uri.parse('$_baseUrl/students/$studentId/activate'), headers: _headers());
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to activate student.');
    }
  }

  Future<void> updateStudent(int studentId, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/students/$studentId'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final res = jsonDecode(response.body);
      throw Exception(res['detail'] ?? 'Failed to update student.');
    }
  }

  Future<void> deleteStudent(int studentId) async {
    final response = await http.delete(Uri.parse('$_baseUrl/students/$studentId'), headers: _headers());
    if (response.statusCode != 200) {
      final res = jsonDecode(response.body);
      throw Exception(res['detail'] ?? 'Failed to delete student.');
    }
  }

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> studentData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/students'),
      headers: _headers(),
      body: jsonEncode(studentData),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to create student.');
  }

  Future<Map<String, dynamic>> bulkImportStudents(List<Map<String, dynamic>> students) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/students/import'),
      headers: _headers(),
      body: jsonEncode(students),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to import students.');
  }

  // --- Inventory APIs ---
  Future<List<dynamic>> getMasterInventory({String? search, String? category}) async {
    var uri = Uri.parse('$_baseUrl/inventory').replace(queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category != 'ALL') 'category': category,
    });
    final response = await http.get(uri, headers: _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to load inventory.');
  }

  Future<Map<String, dynamic>> createMasterInventory(Map<String, dynamic> itemData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/inventory'),
      headers: _headers(),
      body: jsonEncode(itemData),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['data'];
    throw Exception(data['detail'] ?? 'Failed to create inventory item.');
  }
}
