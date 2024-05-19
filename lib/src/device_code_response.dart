
import 'dart:convert';

DeviceCodeResponse deviceCodeResponseFromJson(String str) => DeviceCodeResponse.fromJson(json.decode(str));
String deviceCodeResponseToJson(DeviceCodeResponse data) => json.encode(data.toJson());

class DeviceCodeResponse {
  DeviceCodeResponse({
    String? userCode,
    String? deviceCode,
    String? verificationUri,
    int? expiresIn,
    int? interval,
    String? message,
  }) {
    _userCode = userCode;
    _deviceCode = deviceCode;
    _verificationUri = verificationUri;
    _expiresIn = expiresIn;
    _interval = interval;
    _message = message;
  }

  DeviceCodeResponse.fromJson(dynamic json) {
    _userCode = json['user_code'];
    _deviceCode = json['device_code'];
    _verificationUri = json['verification_uri'];
    _expiresIn = json['expires_in'];
    _interval = json['interval'];
    _message = json['message'];
  }

  String? _userCode;
  String? _deviceCode;
  String? _verificationUri;
  int? _expiresIn;
  int? _interval;
  String? _message;

  DeviceCodeResponse copyWith({
    String? userCode,
    String? deviceCode,
    String? verificationUri,
    int? expiresIn,
    int? interval,
    String? message,
  }) =>
      DeviceCodeResponse(
        userCode: userCode ?? _userCode,
        deviceCode: deviceCode ?? _deviceCode,
        verificationUri: verificationUri ?? _verificationUri,
        expiresIn: expiresIn ?? _expiresIn,
        interval: interval ?? _interval,
        message: message ?? _message,
      );

  String? get userCode => _userCode;

  String? get deviceCode => _deviceCode;

  String? get verificationUri => _verificationUri;

  int? get expiresIn => _expiresIn;

  int? get interval => _interval;

  String? get message => _message;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['user_code'] = _userCode;
    map['device_code'] = _deviceCode;
    map['verification_uri'] = _verificationUri;
    map['expires_in'] = _expiresIn;
    map['interval'] = _interval;
    map['message'] = _message;
    return map;
  }
}
