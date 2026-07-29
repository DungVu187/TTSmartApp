import 'json_helpers.dart';

class ProblemDetails {
  const ProblemDetails({
    this.status,
    this.title,
    this.detail,
    this.traceId,
    this.errors = const <String, List<String>>{},
  });

  factory ProblemDetails.fromJson(Object? value) {
    final json = requireJsonObject(value, 'ProblemDetails');
    final rawErrors = json['errors'];
    final errors = <String, List<String>>{};
    if (rawErrors is Map) {
      for (final entry in rawErrors.entries) {
        final messages = entry.value;
        if (messages is List) {
          errors[entry.key.toString()] = messages.whereType<String>().toList(
            growable: false,
          );
        }
      }
    }

    final rawStatus = json['status'];
    return ProblemDetails(
      status: rawStatus is int ? rawStatus : null,
      title: json['title'] is String ? json['title'] as String : null,
      detail: json['detail'] is String ? json['detail'] as String : null,
      traceId: json['traceId'] is String ? json['traceId'] as String : null,
      errors: errors,
    );
  }

  final int? status;
  final String? title;
  final String? detail;
  final String? traceId;
  final Map<String, List<String>> errors;
}
