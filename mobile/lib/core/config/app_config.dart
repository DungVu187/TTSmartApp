class AppConfig {
  const AppConfig({required this.apiBaseUri, required this.requestTimeout});

  factory AppConfig.fromEnvironment() {
    const rawBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5052',
    );
    final uri = Uri.tryParse(rawBaseUrl);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException(
        'API_BASE_URL phải là một địa chỉ HTTP hoặc HTTPS hợp lệ.',
      );
    }

    return AppConfig(
      apiBaseUri: uri,
      requestTimeout: const Duration(seconds: 30),
    );
  }

  final Uri apiBaseUri;
  final Duration requestTimeout;
}
