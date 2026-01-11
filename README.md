# msal4flutter

## Features

Unofficial Flutter package for The Microsoft Authentication Library (MSAL).

Currently only device authorization of OAuth 2.0 is supported. It works on Android, iOS, MacOS, Windows, Linux.

- ✅ Device Code Flow authentication
- ✅ Automatic token caching and refresh
- ✅ Customizable token storage interface
- ✅ Silent token acquisition

![](https://learn.microsoft.com/en-us/entra/identity-platform/media/v2-oauth2-device-code/v2-oauth-device-flow.svg)

## Usage

### Basic Usage

```dart
final client = PublicClient(
  clientId: 'f522xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx',
  scope: ['Files.ReadWrite'],
);

// Start device code flow
final device = await client.create();
print(device?.message); // Display to user

// Wait for user authentication
final result = await client.acquireTokenInteractive();
print(result.accessToken);
```

### Silent Token Acquisition

```dart
// Try to get token silently (from cache or refresh)
try {
  final result = await client.acquireTokenSilent();
  print(result.accessToken);
} catch (e) {
  // Need interactive login
  final device = await client.create();
  final result = await client.acquireTokenInteractive();
}
```

### Custom Token Storage

Implement `TokenStorage` interface for persistent token storage:

```dart
class SecureTokenStorage implements TokenStorage {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> get(String key) => _storage.read(key: key);

  @override
  Future<void> set(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> remove(String key) => _storage.delete(key: key);
}

// Use custom storage
final client = PublicClient(
  clientId: 'your-client-id',
  scope: ['user.read'],
  storage: SecureTokenStorage(),
);

// Load cached tokens on app start
await client.initialize();
```

### Token Refresh

The library automatically handles token refresh when using `acquireTokenSilent()`. You can also manage token refresh manually:

```dart
// Check token status
if (client.hasValidToken) {
  print('Token is still valid');
}

if (client.canRefresh) {
  print('Refresh token is available');
}

// Force refresh token (even if not expired)
try {
  final result = await client.forceRefresh();
  print('Token refreshed: ${result.accessToken}');
} catch (e) {
  print('Refresh failed, need interactive login');
}

// Access cached token information
final cached = client.cachedToken;
if (cached != null) {
  print('Token expires at: ${cached.expiresAt}');
  print('Is expired: ${cached.isExpired()}');
}
```

#### Expired Refresh Token

If the app has not been used for an extended period, the refresh token may also expire (typically 90 days for Microsoft Entra ID). When this happens:

1. The library automatically clears the cached tokens
2. An exception is thrown from `acquireTokenSilent()` or `forceRefresh()`
3. You need to re-authenticate the user interactively

Recommended pattern for handling this:

```dart
Future<AuthenticationResult> getToken() async {
  try {
    // First try silent acquisition (uses cache or refresh token)
    return await client.acquireTokenSilent();
  } catch (e) {
    // Refresh token expired or no cached token, need interactive login
    final device = await client.create();
    print(device?.message); // Display to user
    return await client.acquireTokenInteractive();
  }
}
```

#### Token Refresh Buffer

Token expiration time is determined by the `expires_in` value returned from the API. The `tokenRefreshBuffer` parameter controls how early to refresh the token **before** it actually expires. This prevents using a token that's about to expire, which could cause request failures.

For example, if the API returns a token valid for 1 hour and `tokenRefreshBuffer` is 300 seconds, the library will consider the token "expired" at 55 minutes and trigger a refresh.

```dart
final client = PublicClient(
  clientId: 'your-client-id',
  scope: ['user.read'],
  tokenRefreshBuffer: 600, // Refresh 10 minutes before actual expiration
);
```

### Sign Out

```dart
await client.signOut(); // Clears cached tokens
```
