import 'dart:convert';

TokenResponse tokenResponseFromJson(String str) => TokenResponse.fromJson(json.decode(str));
String tokenResponseToJson(TokenResponse data) => json.encode(data.toJson());

class TokenResponse {
  TokenResponse({
      String? tokenType, 
      String? scope, 
      int? expiresIn, 
      String? accessToken, 
      String? refreshToken, 
      String? idToken,}){
    _tokenType = tokenType;
    _scope = scope;
    _expiresIn = expiresIn;
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _idToken = idToken;
}

  TokenResponse.fromJson(dynamic json) {
    _tokenType = json['token_type'];
    _scope = json['scope'];
    _expiresIn = json['expires_in'];
    _accessToken = json['access_token'];
    _refreshToken = json['refresh_token'];
    _idToken = json['id_token'];
  }
  String? _tokenType;
  String? _scope;
  int? _expiresIn;
  String? _accessToken;
  String? _refreshToken;
  String? _idToken;
TokenResponse copyWith({  String? tokenType,
  String? scope,
  int? expiresIn,
  String? accessToken,
  String? refreshToken,
  String? idToken,
}) => TokenResponse(  tokenType: tokenType ?? _tokenType,
  scope: scope ?? _scope,
  expiresIn: expiresIn ?? _expiresIn,
  accessToken: accessToken ?? _accessToken,
  refreshToken: refreshToken ?? _refreshToken,
  idToken: idToken ?? _idToken,
);
  String? get tokenType => _tokenType;
  String? get scope => _scope;
  int? get expiresIn => _expiresIn;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get idToken => _idToken;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['token_type'] = _tokenType;
    map['scope'] = _scope;
    map['expires_in'] = _expiresIn;
    map['access_token'] = _accessToken;
    map['refresh_token'] = _refreshToken;
    map['id_token'] = _idToken;
    return map;
  }
}