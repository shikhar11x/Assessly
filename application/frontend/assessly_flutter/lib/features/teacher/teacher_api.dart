import '../../core/api_client.dart';

/// Teacher-side API calls.
class TeacherApi {
  final ApiClient api;
  TeacherApi(this.api);

  List<Map<String, dynamic>> _list(Map<String, dynamic> res, String key) =>
      (res[key] as List).cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> assessments() async =>
      _list(await api.get('/api/teacher/assessments'), 'assessments');

  Future<Map<String, dynamic>> createAssessment(Map<String, dynamic> body) =>
      api.post('/api/teacher/assessments', body);

  Future<Map<String, dynamic>> publish(String id) => api.post('/api/teacher/assessments/$id/publish');
  Future<Map<String, dynamic>> unpublish(String id) => api.post('/api/teacher/assessments/$id/unpublish');

  Future<List<Map<String, dynamic>>> questions(String id) async =>
      _list(await api.get('/api/teacher/assessments/$id/questions'), 'questions');

  Future<Map<String, dynamic>> addQuestion(String id, Map<String, dynamic> body) =>
      api.post('/api/teacher/assessments/$id/questions', body);

  Future<Map<String, dynamic>> deleteQuestion(String id, String qid) =>
      api.delete('/api/teacher/assessments/$id/questions/$qid');

  Future<Map<String, dynamic>> importStudents(String csv) =>
      api.post('/api/teacher/students/import', {'csv': csv});

  Future<Map<String, dynamic>> assignAllEligible(String id) =>
      api.post('/api/teacher/assessments/$id/assign', {'allEligible': true});

  Future<List<Map<String, dynamic>>> assignments(String id) async =>
      _list(await api.get('/api/teacher/assessments/$id/assignments'), 'assignments');

  Future<List<Map<String, dynamic>>> submissions(String id) async =>
      _list(await api.get('/api/teacher/assessments/$id/submissions'), 'submissions');

  Future<Map<String, dynamic>> analytics(String id) => api.get('/api/teacher/assessments/$id/analytics');
}
