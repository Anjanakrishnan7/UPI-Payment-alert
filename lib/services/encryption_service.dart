import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class EncryptionService {
  static const String _keyName = 'hive_encryption_key';
  static const String _boxName = 'payments';
  static const _secureStorage = FlutterSecureStorage();

  /// Initializes Hive, handles encryption keys, migrates legacy data, and opens the box securely.
  static Future<Box> openEncryptedBox() async {
    try {
      // 1. Check if we already have a saved encryption key
      final containsKey = await _secureStorage.containsKey(key: _keyName);
      
      if (!containsKey) {
        debugPrint("[EncryptionService] No encryption key found. This is either a first launch or an upgrade from an unencrypted version.");
        
        // Check for existing legacy unencrypted data
        List<dynamic>? legacyData;
        bool hasLegacyBox = false;

        try {
          if (await Hive.boxExists(_boxName)) {
            debugPrint("[EncryptionService] Unencrypted box file detected. Attempting to read legacy records...");
            final tempBox = await Hive.openBox(_boxName);
            if (tempBox.containsKey('history')) {
              legacyData = tempBox.get('history');
              hasLegacyBox = true;
              debugPrint("[EncryptionService] Successfully retrieved ${legacyData?.length} legacy transaction records.");
            }
            await tempBox.close();
          }
        } catch (e) {
          debugPrint("[EncryptionService] Failed to check or read legacy unencrypted box: $e");
        }

        // Generate a new 256-bit (32 bytes) key
        final newKey = Hive.generateSecureKey();
        await _secureStorage.write(
          key: _keyName,
          value: base64UrlEncode(newKey),
        );
        debugPrint("[EncryptionService] Generated and stored a new 256-bit AES key securely.");

        if (hasLegacyBox) {
          debugPrint("[EncryptionService] Migrating legacy data to the new encrypted database...");
          // Delete old unencrypted files from disk before recreating
          await Hive.deleteBoxFromDisk(_boxName);
          
          // Re-open with encryption and write back legacy data
          final encryptedBox = await Hive.openBox(
            _boxName,
            encryptionCipher: HiveAesCipher(newKey),
          );
          if (legacyData != null) {
            await encryptedBox.put('history', legacyData);
          }
          debugPrint("[EncryptionService] Migration completed successfully.");
          return encryptedBox;
        } else {
          // Normal first-time secure box opening
          return await Hive.openBox(
            _boxName,
            encryptionCipher: HiveAesCipher(newKey),
          );
        }
      } else {
        // Key exists, read and reuse it
        debugPrint("[EncryptionService] Encryption key found. Loading key and opening encrypted box...");
        final base64Key = await _secureStorage.read(key: _keyName);
        if (base64Key == null) {
          throw Exception("Stored key was null.");
        }
        final keyBytes = base64Url.decode(base64Key);

        try {
          return await Hive.openBox(
            _boxName,
            encryptionCipher: HiveAesCipher(keyBytes),
          );
        } catch (e) {
          debugPrint("[EncryptionService] Failed to open encrypted box (possibly key or box corruption): $e");
          // Recovery: delete corrupted box files and open a clean one
          await Hive.deleteBoxFromDisk(_boxName);
          return await Hive.openBox(
            _boxName,
            encryptionCipher: HiveAesCipher(keyBytes),
          );
        }
      }
    } catch (e) {
      debugPrint("[EncryptionService] Critical error in openEncryptedBox: $e");
      // Fallback: Attempt to open unencrypted to avoid bricking the app if secure storage fails completely
      return await Hive.openBox(_boxName);
    }
  }
}
