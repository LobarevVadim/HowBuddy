class ApiSession {
  ApiSession._();

  static String? _token;

  static void setToken(String token) => _token = token;

  static void clear() => _token = null;

  static Map<String, String> get authenticatedHeaders => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };
}
