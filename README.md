# msal4flutter

## Features

Unofficial Flutter package for The Microsoft Authentication Library (MSAL).

Currently only device authorization of OAuth 2.0 is supported.It works on Android, iOS, MacOS, Windows, Linux.

![](https://learn.microsoft.com/en-us/entra/identity-platform/media/v2-oauth2-device-code/v2-oauth-device-flow.svg)

## Usage

```dart
    final client =  PublicClient(
        clientId: 'f522xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx',
        scope: ["Files.ReadWrite"]);

    final device = await client.create();
    print(device?.userCode);
    print(device?.expiresIn);
    print(device?.message);
    final token = await client.acquireTokenInteractive();
    print(token.accessToken);
```
