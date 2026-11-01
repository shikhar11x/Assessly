import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// Base class for all app-level errors shown to the user.
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];

  /// Converts a [DioException] into an app-level [Failure].
  static Failure fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure(
          'Unable to reach the server. Please check your connection.',
        );
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        final message = (data is Map && data['message'] is String)
            ? data['message'] as String
            : 'Server error (${e.response?.statusCode}).';
        return ServerFailure(message);
      default:
        return const UnknownFailure('Something went wrong. Please try again.');
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