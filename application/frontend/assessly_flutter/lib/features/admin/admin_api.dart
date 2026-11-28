import '../../core/api_client.dart';

/// Admin-side API calls.
class AdminApi {
  final ApiClient api;
  AdminApi(this.api);

  List<Map<String, dynamic>> _list(Map<String, dynamic> r, String k) => (r[k] as List).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> stats() => api.get('/api/admin/stats');

  Future<List<Map<String, dynamic>>> departments() async => _list(await api.get('/api/admin/departments'), 'departments');
  Future<void> addDepartment(String name, String code) => api.post('/api/admin/departments', {'name': name, 'code': code});
  Future<void> deleteDepartment(String id) => api.delete('/api/admin/departments/$id');

  Future<List<Map<String, dynamic>>> courses() async => _list(await api.get('/api/admin/courses'), 'courses');
  Future<void> addCourse(Map<String, dynamic> body) => api.post('/api/admin/courses', body);
  Future<void> deleteCourse(String id) => api.delete('/api/admin/courses/$id');

  Future<List<Map<String, dynamic>>> batches() async => _list(await api.get('/api/admin/batches'), 'batches');
  Future<void> addBatch(Map<String, dynamic> body) => api.post('/api/admin/batches', body);
  Future<void> deleteBatch(String id) => api.delete('/api/admin/batches/$id');
  Future<List<Map<String, dynamic>>> batchStudents(String id) async =>
      _list(await api.get('/api/admin/batches/$id/students'), 'students');
  Future<Map<String, dynamic>> importToBatch(String id, String csv) =>
      api.post('/api/admin/batches/$id/import', {'csv': csv});
  Future<void> unenroll(String batchId, String studentId) =>
      api.delete('/api/admin/batches/$batchId/students/$studentId');

  Future<Map<String, dynamic>> students(String q) =>
      api.get('/api/admin/students?q=${Uri.encodeQueryComponent(q)}&limit=100');
  Future<Map<String, dynamic>> enroll(String batchId, List<String> ids) =>
      api.post('/api/admin/batches/$batchId/enroll', {'studentIds': ids});
  Future<Map<String, dynamic>> assignBatch(String assessmentId, String batchId) =>
      api.post('/api/admin/assessments/$assessmentId/assign-batch', {'batchId': batchId});
  Future<void> setAttendance(String studentId, double pct) =>
      api.put('/api/teacher/students/$studentId/attendance', {'attendancePct': pct});

  Future<Map<String, dynamic>> addFaculty(Map<String, dynamic> body) => api.post('/api/admin/faculty', body);
  Future<Map<String, dynamic>> users(String role) => api.get('/api/admin/users?role=$role&limit=100');
}
