/// Abstract interface for token storage.
/// Implement this interface to provide custom token persistence.
///
/// Example:
/// ```dart
/// class SecureTokenStorage implements TokenStorage {
///   final FlutterSecureStorage _storage = FlutterSecureStorage();
///
///   @override
///   Future<String?> get(String key) => _storage.read(key: key);
///
///   @override
///   Future<void> set(String key, String value) => _storage.write(key: key, value: value);
///
///   @override
///   Future<void> remove(String key) => _storage.delete(key: key);
/// }
/// ```
abstract class TokenStorage {
  /// Get value by key
  Future<String?> get(String key);

  /// Set key-value pair
  Future<void> set(String key, String value);

  /// Remove value by key
  Future<void> remove(String key);
}

/// In-memory implementation of [TokenStorage].
/// Tokens will be lost when the app is closed.
class InMemoryTokenStorage implements TokenStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> get(String key) async => _store[key];

  @override
  Future<void> set(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }
}
