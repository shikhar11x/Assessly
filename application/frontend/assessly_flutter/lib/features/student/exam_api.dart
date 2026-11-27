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
}
