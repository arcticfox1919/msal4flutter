## 0.1.0
* Added automatic token caching and refresh support
* Added `TokenStorage` interface for custom persistent storage
* Added `acquireTokenSilent()` for silent token acquisition
* Added `forceRefresh()` and `signOut()` methods
* Improved error handling for device code flow
* **Breaking:** `acquireTokenSilent()` and `acquireTokenInteractive()` now return `AuthenticationResult`

## 0.0.2
* Upgrade the [gio](https://pub.dev/packages/gio) library

## 0.0.1

* Only supports device authorization of OAuth 2.0.
