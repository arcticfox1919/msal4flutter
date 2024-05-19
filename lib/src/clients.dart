import 'dart:async';

import 'package:gio/gio.dart';
import 'package:msal4flutter/src/device_code_response.dart';
import 'package:url_launcher/url_launcher.dart';

import 'token_response.dart';

const _header = {'content-type': 'application/x-www-form-urlencoded'};

class PublicClient {
  late final Gio _gio;
  final String tenant;
  final String clientId;
  final List<String> scope;
  final _completer = Completer<DeviceCodeResponse?>();
  Timer? _timer;

  ///
  /// see:https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code
  /// [debug] is set to true, logs can be printed
  ///
  PublicClient(
      {this.tenant = 'common',
      required this.clientId,
      required this.scope,
      bool? debug}) {
    Gio.option = GioOption(
        basePath: 'https://login.microsoftonline.com',
        enableLog: debug ?? false);
    _gio = Gio();
  }

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

  Future<TokenResponse> acquireTokenSilent() async {
    final device = await _completer.future;
    if (device != null) {
      return _createPollTask(device);
    } else {
      throw Exception('devicecode request failed!');
    }
  }

  Future<TokenResponse> acquireTokenInteractive() async {
    final device = await _completer.future;
    if (device != null) {
      final url = Uri.parse(device.verificationUri!);
      launchUrl(url).then((value) {
        if (!value) {
          throw Exception('Could not launch $url');
        }
      });
      return _createPollTask(device);
    } else {
      throw Exception('devicecode request failed!');
    }
  }

  Future<TokenResponse> _createPollTask(DeviceCodeResponse device) {
    final timeoutSeconds = Duration(seconds: device.expiresIn!);
    final result = Completer<TokenResponse>();
    _timer = Timer.periodic(Duration(seconds: device.interval!), (timer) async {
      final resp =
          await _gio.post('$tenant/oauth2/v2.0/token', headers: _header, body: {
        'client_id': clientId,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        'device_code': device.deviceCode
      });

      if (resp.statusCode == 200) {
        timer.cancel();
        result.complete(tokenResponseFromJson(resp.body));
      }
    });

    return result.future.timeout(timeoutSeconds);
  }

  void dispose() {
    _timer?.cancel();
    _gio.close();
  }
}
