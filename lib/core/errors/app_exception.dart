class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

class NetworkException extends AppException {
  const NetworkException([String message = 'No internet connection.'])
      : super(message, code: 'network');
}

class FirestoreException extends AppException {
  const FirestoreException(super.message, {super.code});
}

class OcrException extends AppException {
  const OcrException(super.message, {super.code});
}

class StorageException extends AppException {
  const StorageException(super.message, {super.code});
}

