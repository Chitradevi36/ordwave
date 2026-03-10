import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys used in secure storage.
class _Keys {
  static const authToken      = 'auth_token';
  static const organizationId = 'organization_id';
  static const branchId       = 'branch_id';
  static const userJson       = 'user_json';
}

/// Thin wrapper around [FlutterSecureStorage] for auth credentials.
class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> getToken()          => _storage.read(key: _Keys.authToken);
  Future<String?> getOrganizationId() => _storage.read(key: _Keys.organizationId);
  Future<String?> getBranchId()       => _storage.read(key: _Keys.branchId);
  Future<String?> getUserJson()       => _storage.read(key: _Keys.userJson);

  Future<void> saveAuthData({
    required String token,
    required String organizationId,
    String? branchId,
    String? userJson,
  }) async {
    await Future.wait([
      _storage.write(key: _Keys.authToken,      value: token),
      _storage.write(key: _Keys.organizationId, value: organizationId),
      if (branchId != null)
        _storage.write(key: _Keys.branchId, value: branchId),
      if (userJson != null)
        _storage.write(key: _Keys.userJson, value: userJson),
    ]);
  }

  /// Update only the access token (used after a silent refresh).
  Future<void> saveToken(String token) =>
      _storage.write(key: _Keys.authToken, value: token);

  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _Keys.authToken),
      _storage.delete(key: _Keys.organizationId),
      _storage.delete(key: _Keys.branchId),
      _storage.delete(key: _Keys.userJson),
    ]);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return SecureStorageService(storage);
});
