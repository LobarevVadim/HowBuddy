class ApiSession {
  ApiSession._();

  static String? _token;
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://howbuddy-demo-api.onrender.com',
  );

  static void setToken(String token) => _token = token;
  static void clear() => _token = null;

  static Map<String, String> get authenticatedHeaders => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };
}

class ApiSessionException implements Exception {
  const ApiSessionException(this.message);
  final String message;
}
