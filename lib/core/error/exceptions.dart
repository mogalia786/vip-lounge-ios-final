/// Base class for all app-specific exceptions
class AppException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  const AppException(this.message, [this.stackTrace]);

  @override
  String toString() => 'AppException: $message';
}

/// Thrown when there's an error communicating with the server
class ServerException extends AppException {
  const ServerException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Thrown when there's an error with local data storage
class CacheException extends AppException {
  const CacheException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Thrown when there's an error with the device's network connection
class NetworkException extends AppException {
  const NetworkException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Thrown when there's an error with user input validation
class ValidationException extends AppException {
  const ValidationException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Thrown when a requested resource is not found
class NotFoundException extends AppException {
  const NotFoundException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Thrown when a user is not authorized to perform an action
class UnauthorizedException extends AppException {
  const UnauthorizedException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Thrown when an action is not allowed in the current state
class InvalidStateException extends AppException {
  const InvalidStateException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}
