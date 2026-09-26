import 'dart:async';

class ApiRequestCancellation {
  final Completer<void> _completer = Completer<void>();

  Future<void> get whenCancelled => _completer.future;

  bool get isCancelled => _completer.isCompleted;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

class ApiRequestCancelledException implements Exception {
  const ApiRequestCancelledException();
}

/// The newest request of one kind. Starting the next one, or leaving the
/// screen, cancels it: the connection closes and the API stops the query on
/// the station database instead of finishing an answer nobody will read.
class LatestApiRequest {
  ApiRequestCancellation? _current;

  ApiRequestCancellation next() {
    _current?.cancel();
    return _current = ApiRequestCancellation();
  }

  void cancel() {
    _current?.cancel();
    _current = null;
  }
}
