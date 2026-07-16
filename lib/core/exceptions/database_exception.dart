class DatabaseException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  DatabaseException(this.message, {this.code, this.originalError});

  @override
  String toString() {
    if (code != null) {
      return 'DatabaseException [$code]: $message';
    }
    return 'DatabaseException: $message';
  }
}

class RecordNotFoundException extends DatabaseException {
  RecordNotFoundException(super.message) : super(code: 'NOT_FOUND');
}

class DuplicateRecordException extends DatabaseException {
  DuplicateRecordException(super.message) : super(code: 'DUPLICATE');
}

class ForeignKeyException extends DatabaseException {
  ForeignKeyException(super.message) : super(code: 'FK_VIOLATION');
}

class ValidationException extends DatabaseException {
  ValidationException(super.message) : super(code: 'VALIDATION');
}
