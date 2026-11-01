import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];

  /// Dio errors ko app-level Failure mein convert karta hai.
  static Failure fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure('Server se connect nahi ho paa raha.');
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        final msg = (data is Map && data['message'] is String)
            ? data['message'] as String
            : 'Server error (${e.response?.statusCode}).';
        return ServerFailure(msg);
      default:
        return const UnknownFailure('Kuch galat ho gaya.');
    }
  }
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}