import 'dart:convert';

import 'token_response.dart';

/// Keys used for token storage
class TokenCacheKeys {
  static const String accessToken = 'msal_access_token';
  static const String refreshToken = 'msal_refresh_token';
  static const String idToken = 'msal_id_token';
  static const String expiresAt = 'msal_expires_at';
  static const String tokenResponse = 'msal_token_response';
}

/// Cached token with expiration information
class CachedToken {
  final TokenResponse tokenResponse;
  final DateTime expiresAt;

  CachedToken({
    required this.tokenResponse,
    required this.expiresAt,
  });

  /// Check if the token is expired
  /// [bufferSeconds] is the buffer time before actual expiration (default 5 minutes)
  bool isExpired({int bufferSeconds = 300}) {
    return DateTime.now()
        .isAfter(expiresAt.subtract(Duration(seconds: bufferSeconds)));
  }

  /// Check if the token can be refreshed (has refresh token)
  bool get canRefresh =>
      tokenResponse.refreshToken != null &&
      tokenResponse.refreshToken!.isNotEmpty;

  /// Create from TokenResponse
  factory CachedToken.fromTokenResponse(TokenResponse response) {
    final expiresIn = response.expiresIn ?? 3600;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    return CachedToken(
      tokenResponse: response,
      expiresAt: expiresAt,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'token_response': tokenResponse.toJson(),
      'expires_at': expiresAt.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON
  factory CachedToken.fromJson(Map<String, dynamic> json) {
    return CachedToken(
      tokenResponse: TokenResponse.fromJson(json['token_response']),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expires_at']),
    );
  }

  /// Serialize to string
  String serialize() => jsonEncode(toJson());

  /// Deserialize from string
  static CachedToken? deserialize(String? str) {
    if (str == null || str.isEmpty) return null;
    try {
      return CachedToken.fromJson(jsonDecode(str));
    } catch (e) {
      return null;
    }
  }
}
