import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final StackTrace? stackTrace;

  const Failure(this.message, [this.stackTrace]);

  @override
  List<Object?> get props => [message, stackTrace];

  @override
  String toString() => 'Failure: $message';
}

class ServerFailure extends Failure {
  const ServerFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

class CacheFailure extends Failure {
  const CacheFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

class ValidationFailure extends Failure {
  const ValidationFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

class InvalidStateFailure extends Failure {
  const InvalidStateFailure(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}
