import 'dart:async';

import 'package:gio/gio.dart';
import 'package:msal4flutter/src/device_code_response.dart';
import 'package:msal4flutter/src/token_cache.dart';
import 'package:msal4flutter/src/token_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'token_response.dart';

const _header = {'content-type': 'application/x-www-form-urlencoded'};

/// Authentication result containing token and1 account information
class AuthenticationResult {
  final String accessToken;
  final String? idToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final List<String> scopes;

  AuthenticationResult({
    required this.accessToken,
    this.idToken,
    this.refreshToken,
    required this.expiresAt,
    required this.scopes,
  });

  /// Check if the token is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Create from CachedToken
  factory AuthenticationResult.fromCachedToken(CachedToken cachedToken) {
    return AuthenticationResult(
      accessToken: cachedToken.tokenResponse.accessToken!,
      idToken: cachedToken.tokenResponse.idToken,
      refreshToken: cachedToken.tokenResponse.refreshToken,
      expiresAt: cachedToken.expiresAt,
      scopes: cachedToken.tokenResponse.scope?.split(' ') ?? [],
    );
  }
}

/// OAuth 2.0 Device Authorization Grant client
///
/// Implements the device code flow for public clients as specified in:
/// https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code
///
/// Features:
/// - Automatic token caching and refresh
/// - Customizable token storage via [TokenStorage] interface
/// - Silent token acquisition with automatic refresh
/// - Interactive token acquisition with browser launch
///
/// Example:
/// ```dart
/// final client = PublicClient(
///   clientId: 'your-client-id',
///   scope: ['user.read'],
///   storage: MyCustomTokenStorage(), // Optional: implement TokenStorage
/// );
///
/// // Start device code flow
/// final deviceCode = await client.create();
/// print('Please visit ${deviceCode?.verificationUri} and enter code: ${deviceCode?.userCode}');
///
/// // Wait for user authentication
/// final result = await client.acquireTokenInteractive();
/// print('Access token: ${result.accessToken}');
///
/// // Later: get cached token or refresh silently
/// final cachedResult = await client.acquireTokenSilent();
/// ```
class PublicClient {
  late final Gio _gio;
  final String tenant;
  final String clientId;
  final List<String> _scope;
  final TokenStorage _storage;
  final _completer = Completer<DeviceCodeResponse?>();
  Timer? _timer;
  CachedToken? _cachedToken;

  /// Buffer time (in seconds) before token expiration to trigger refresh
  /// Default: 5 minutes (300 seconds)
  final int tokenRefreshBuffer;

  /// Get the effective scopes (including offline_access)
  List<String> get scope => _scope;

  ///
  /// Create a new PublicClient for device code authentication flow.
  ///
  /// [tenant] - Azure AD tenant ID or 'common' for multi-tenant apps
  /// [clientId] - Application (client) ID from Azure AD
  /// [scope] - List of OAuth scopes to request
  /// [storage] - Custom token storage implementation. Defaults to in-memory storage
  /// [tokenRefreshBuffer] - Seconds before expiration to refresh token (default: 300)
  /// [debug] - Enable debug logging
  ///
  /// Note: 'offline_access' scope is automatically added to enable token refresh.
  ///
  /// See: https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code
  ///
  PublicClient({
    this.tenant = 'common',
    required this.clientId,
    required List<String> scope,
    TokenStorage? storage,
    this.tokenRefreshBuffer = 300,
    bool? debug,
  })  : _scope = _ensureOfflineAccess(scope),
        _storage = storage ?? InMemoryTokenStorage() {
    _gio = Gio.withOption(GioOption(
        basePath: 'https://login.microsoftonline.com',
        enableLog: debug ?? false));
  }

  /// Ensure offline_access scope is included for refresh token support
  static List<String> _ensureOfflineAccess(List<String> scopes) {
    const offlineAccess = 'offline_access';
    if (scopes.any((s) => s.toLowerCase() == offlineAccess)) {
      return scopes;
    }
    return [...scopes, offlineAccess];
  }

  /// Get the storage key for tokens (unique per client/tenant combination)
  String get _storageKey => 'msal_${clientId}_$tenant';

  /// Initialize the client and load cached tokens
  Future<void> initialize() async {
    await _loadCachedToken();
  }

  /// Load cached token from storage
  Future<void> _loadCachedToken() async {
    final stored = await _storage.get(_storageKey);
    _cachedToken = CachedToken.deserialize(stored);
  }

  /// Save token to cache and storage
  Future<void> _saveToken(TokenResponse response) async {
    _cachedToken = CachedToken.fromTokenResponse(response);
    await _storage.set(_storageKey, _cachedToken!.serialize());
  }

  /// Clear cached tokens
  Future<void> clearTokens() async {
    _cachedToken = null;
    await _storage.remove(_storageKey);
  }

  /// Check if there is a valid cached token
  bool get hasValidToken {
    if (_cachedToken == null) return false;
    return !_cachedToken!.isExpired(bufferSeconds: tokenRefreshBuffer);
  }

  /// Check if there is a refresh token available
  bool get canRefresh => _cachedToken?.canRefresh ?? false;

  /// Get current cached token (may be expired)
  CachedToken? get cachedToken => _cachedToken;

  Future<DeviceCodeResponse?> _getDeviceCode() async {
    final resp = await _gio.post('$tenant/oauth2/v2.0/devicecode',
        headers: _header,
        body: {'client_id': clientId, 'scope': scope.join(' ')});

    if (resp.statusCode == 200) {
      return deviceCodeResponseFromJson(resp.body);
    } else {
      throw Exception(resp.body);
    }
  }

  /// Start the device code flow and return the device code response
  ///
  /// Returns [DeviceCodeResponse] containing:
  /// - [userCode] - Code to display to user
  /// - [verificationUri] - URL for user to visit
  /// - [message] - User-friendly message to display
  Future<DeviceCodeResponse?> create() async {
    try {
      final resp = await _getDeviceCode();
      _completer.complete(resp);
      return resp;
    } catch (e) {
      _completer.completeError(e);
    }
    return null;
  }

  /// Acquire token silently from cache or by refreshing
  ///
  /// This method will:
  /// 1. Return cached token if still valid
  /// 2. Refresh token using refresh_token if available and token expired
  /// 3. Wait for pending device code flow if in progress
  ///
  /// Throws [Exception] if no valid token available and cannot refresh
  Future<AuthenticationResult> acquireTokenSilent() async {
    // First, try to load from storage if not in memory
    if (_cachedToken == null) {
      await _loadCachedToken();
    }

    // Return cached token if valid
    if (hasValidToken) {
      return AuthenticationResult.fromCachedToken(_cachedToken!);
    }

    // Try to refresh if we have a refresh token
    if (canRefresh) {
      final refreshed = await _refreshToken();
      return AuthenticationResult.fromCachedToken(refreshed);
    }

    // Fall back to waiting for device code flow
    if (!_completer.isCompleted) {
      final device = await _completer.future;
      if (device != null) {
        final response = await _createPollTask(device);
        await _saveToken(response);
        return AuthenticationResult.fromCachedToken(_cachedToken!);
      }
    }

    throw Exception(
        'No valid token available. Please use acquireTokenInteractive().');
  }

  /// Refresh the access token using the refresh token
  ///
  /// See: https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow#refresh-the-access-token
  Future<CachedToken> _refreshToken() async {
    if (_cachedToken?.tokenResponse.refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final resp =
        await _gio.post('$tenant/oauth2/v2.0/token', headers: _header, body: {
      'client_id': clientId,
      'grant_type': 'refresh_token',
      'refresh_token': _cachedToken!.tokenResponse.refreshToken,
      'scope': scope.join(' '),
    });

    if (resp.statusCode == 200) {
      final tokenResponse = tokenResponseFromJson(resp.body);
      await _saveToken(tokenResponse);
      return _cachedToken!;
    } else {
      // Refresh token may be expired or revoked, clear cache
      await clearTokens();
      throw Exception('Failed to refresh token: ${resp.body}');
    }
  }

  /// Acquire token interactively using device code flow
  ///
  /// This method will:
  /// 1. Launch the verification URL in the browser
  /// 2. Poll for token until user completes authentication
  /// 3. Cache the obtained tokens
  ///
  /// Returns [AuthenticationResult] with tokens and expiration info
  Future<AuthenticationResult> acquireTokenInteractive() async {
    final device = await _completer.future;
    if (device != null) {
      final url = Uri.parse(device.verificationUri!);
      launchUrl(url).then((value) {
        if (!value) {
          throw Exception('Could not launch $url');
        }
      });
      final response = await _createPollTask(device);
      await _saveToken(response);
      return AuthenticationResult.fromCachedToken(_cachedToken!);
    } else {
      throw Exception('Device code request failed!');
    }
  }

  /// Force refresh the token even if not expired
  Future<AuthenticationResult> forceRefresh() async {
    if (!canRefresh) {
      throw Exception(
          'No refresh token available. Please use acquireTokenInteractive().');
    }
    final refreshed = await _refreshToken();
    return AuthenticationResult.fromCachedToken(refreshed);
  }

  Future<TokenResponse> _createPollTask(DeviceCodeResponse device) {
    final timeoutSeconds = Duration(seconds: device.expiresIn!);
    final result = Completer<TokenResponse>();
    _timer = Timer.periodic(Duration(seconds: device.interval!), (timer) async {
      try {
        final resp = await _gio
            .post('$tenant/oauth2/v2.0/token', headers: _header, body: {
          'client_id': clientId,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'device_code': device.deviceCode
        });

        if (resp.statusCode == 200) {
          timer.cancel();
          result.complete(tokenResponseFromJson(resp.body));
        } else {
          // Handle specific error responses
          final body = resp.body;
          if (body.contains('authorization_pending')) {
            // User hasn't completed auth yet, continue polling
            return;
          } else if (body.contains('authorization_declined')) {
            timer.cancel();
            result.completeError(Exception('User declined authorization'));
          } else if (body.contains('bad_verification_code')) {
            timer.cancel();
            result.completeError(Exception('Invalid device code'));
          } else if (body.contains('expired_token')) {
            timer.cancel();
            result.completeError(Exception('Device code expired'));
          }
        }
      } catch (e) {
        // Network error, continue polling
      }
    });

    return result.future.timeout(timeoutSeconds, onTimeout: () {
      _timer?.cancel();
      throw TimeoutException('Device code flow timed out', timeoutSeconds);
    });
  }

  /// Sign out and clear all cached tokens
  Future<void> signOut() async {
    await clearTokens();
  }

  void dispose() {
    _timer?.cancel();
    _gio.close();
  }
}
