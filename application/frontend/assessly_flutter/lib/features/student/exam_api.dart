import 'student_api.dart';

/// Calls used while an exam is running.
extension ExamApi on StudentApi {
  /// Saves the full answer state of one question (the server replaces it).
  Future<Map<String, dynamic>> saveAnswer(String attemptId, String questionId,
          {int? selectedOption, String? code, required bool marked}) =>
      api.put('/api/student/attempts/$attemptId/answers/$questionId',
          {'selectedOption': selectedOption, 'code': code, 'markedForReview': marked});

  Future<Map<String, dynamic>> submit(String attemptId) =>
      api.post('/api/student/attempts/$attemptId/submit');

  Future<Map<String, dynamic>> tabSwitch(String attemptId) =>
      api.post('/api/student/attempts/$attemptId/tab-switch');

  /// Runs the code against the sample test case only.
  Future<Map<String, dynamic>> runCode(String attemptId, String questionId, String code) =>
      api.post('/api/student/attempts/$attemptId/questions/$questionId/run', {'code': code});

  /// Runs the code against every test case and stores the marks.
  Future<Map<String, dynamic>> submitCode(String attemptId, String questionId, String code) =>
      api.post('/api/student/attempts/$attemptId/questions/$questionId/submit-code', {'code': code});

  Future<Map<String, dynamic>> result(String attemptId) =>
      api.get('/api/student/attempts/$attemptId/result');
}
