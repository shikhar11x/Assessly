import '../../core/api_client.dart';

class AssessmentItem {
  final String id;
  final String title;
  final String description;
  final int durationMinutes;
  final int questionsPerAttempt;
  final double minAttendancePct;
  final bool eligible;
  final String? attemptId;
  final String attemptStatus; // not_started | in_progress | submitted | expired
  final double? score;
  final double? maxScore;

  AssessmentItem({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.questionsPerAttempt,
    required this.minAttendancePct,
    required this.eligible,
    required this.attemptId,
    required this.attemptStatus,
    required this.score,
    required this.maxScore,
  });

  factory AssessmentItem.fromJson(Map<String, dynamic> j) => AssessmentItem(
        id: j['id'] as String,
        title: j['title'] as String,
        description: (j['description'] ?? '') as String,
        durationMinutes: j['durationMinutes'] as int,
        questionsPerAttempt: j['questionsPerAttempt'] as int,
        minAttendancePct: (j['minAttendancePct'] as num).toDouble(),
        eligible: j['eligible'] as bool,
        attemptId: j['attemptId'] as String?,
        attemptStatus: (j['attemptStatus'] ?? 'not_started') as String,
        score: (j['score'] as num?)?.toDouble(),
        maxScore: (j['maxScore'] as num?)?.toDouble(),
      );

  bool get inProgress => attemptStatus == 'in_progress';
  bool get closed => attemptStatus == 'submitted' || attemptStatus == 'expired';
}

class DashboardData {
  final double attendancePct;
  final List<AssessmentItem> assessments;
  DashboardData(this.attendancePct, this.assessments);
}

/// Student-side API calls.
class StudentApi {
  final ApiClient api;
  StudentApi(this.api);

  Future<DashboardData> dashboard() async {
    final res = await api.get('/api/student/assessments');
    final list = (res['assessments'] as List)
        .map((e) => AssessmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return DashboardData((res['attendancePct'] as num).toDouble(), list);
  }

  /// Creates the attempt (random questions, server-side deadline). Returns the attempt id.
  Future<String> start(String assessmentId) async {
    final res = await api.post('/api/student/assessments/$assessmentId/start');
    return (res['attempt'] as Map<String, dynamic>)['id'] as String;
  }

  Future<Map<String, dynamic>> attempt(String attemptId) =>
      api.get('/api/student/attempts/$attemptId');
}
