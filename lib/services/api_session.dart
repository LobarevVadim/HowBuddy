class ApiSession {
  ApiSession._();

  static String? _token;

  static void setToken(String token) => _token = token;

  static void clear() => _token = null;

  static String get _localDate {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static Map<String, String> get authenticatedHeaders => {
    'Content-Type': 'application/json',
    'X-Client-Date': _localDate,
    if (_token != null) 'Authorization': 'Bearer $_token',
  };
}
