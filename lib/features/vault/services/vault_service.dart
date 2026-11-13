import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/vault_document.dart';

/// Local-first encrypted vault. The index and every document are encrypted
/// with AES-256-GCM. The vault key is held in platform secure storage.
class VaultService {
  VaultService._();
  static final VaultService instance = VaultService._();

  static const _storage = FlutterSecureStorage();
  static const _keyName = 'sanj_ai_vault_key_v1';
  static const _pinSaltName = 'sanj_ai_pin_salt_v1';
  static const _pinHashName = 'sanj_ai_pin_hash_v1';
  static const _indexName = 'vault_index.enc';
  static const _vaultFolder = 'sanj_ai_vault';

  final _cipher = AesGcm.with256bits();
  final _uuid = const Uuid();
  SecretKey? _vaultKey;

  Future<Directory> _directory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, _vaultFolder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<bool> isConfigured() async =>
      (await _storage.read(key: _pinHashName)) != null;

  Future<void> setupPin(String pin) async {
    if (pin.length < 6) throw ArgumentError('PIN must be at least 6 digits.');
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final hash = await _derivePinHash(pin, salt);
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    await _storage.write(key: _pinSaltName, value: base64Encode(salt));
    await _storage.write(key: _pinHashName, value: base64Encode(hash));
    await _storage.write(key: _keyName, value: base64Encode(keyBytes));
    _vaultKey = SecretKey(keyBytes);
    await _saveIndex(const []);
  }

  Future<List<int>> _derivePinHash(String pin, List<int> salt) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 120000,
      bits: 256,
    );
    final derived = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return derived.extractBytes();
  }

  Future<bool> verifyPin(String pin) async {
    final saltValue = await _storage.read(key: _pinSaltName);
    final hashValue = await _storage.read(key: _pinHashName);
    if (saltValue == null || hashValue == null) return false;
    final candidate = await _derivePinHash(pin, base64Decode(saltValue));
    final expected = base64Decode(hashValue);
    if (candidate.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate[i] ^ expected[i];
    }
    if (diff != 0) return false;
    await _loadKey();
    return true;
  }

  Future<void> unlockAfterBiometric() => _loadKey();

  Future<void> _loadKey() async {
    final value = await _storage.read(key: _keyName);
    if (value == null) throw StateError('Vault key is missing.');
    _vaultKey = SecretKey(base64Decode(value));
  }

  void lock() => _vaultKey = null;

  void _requireUnlocked() {
    if (_vaultKey == null) throw StateError('Unlock the vault first.');
  }

  Future<Uint8List> _encrypt(List<int> clearBytes) async {
    _requireUnlocked();
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      clearBytes,
      secretKey: _vaultKey!,
      nonce: nonce,
    );
    // Format: nonce (12) + MAC (16) + ciphertext.
    return Uint8List.fromList([...nonce, ...box.mac.bytes, ...box.cipherText]);
  }

  Future<Uint8List> _decrypt(List<int> bytes) async {
    _requireUnlocked();
    if (bytes.length < 28) throw const FormatException('Invalid encrypted file.');
    final nonce = bytes.sublist(0, 12);
    final mac = Mac(bytes.sublist(12, 28));
    final cipherText = bytes.sublist(28);
    final clear = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: _vaultKey!,
    );
    return Uint8List.fromList(clear);
  }

  Future<List<VaultDocument>> listDocuments() async {
    _requireUnlocked();
    final dir = await _directory();
    final index = File(p.join(dir.path, _indexName));
    if (!await index.exists()) return [];
    final clear = await _decrypt(await index.readAsBytes());
    final decoded = jsonDecode(utf8.decode(clear)) as List<dynamic>;
    return decoded
        .map((item) => VaultDocument.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  Future<void> _saveIndex(List<VaultDocument> docs) async {
    _requireUnlocked();
    final dir = await _directory();
    final encrypted = await _encrypt(utf8.encode(
      jsonEncode(docs.map((doc) => doc.toJson()).toList()),
    ));
    await File(p.join(dir.path, _indexName)).writeAsBytes(encrypted, flush: true);
  }

  Future<void> importBytes({
    required String name,
    required String member,
    required String category,
    required List<int> bytes,
  }) async {
    _requireUnlocked();
    if (bytes.isEmpty) throw ArgumentError('The selected file is empty.');
    final id = _uuid.v4();
    final encrypted = await _encrypt(bytes);
    final dir = await _directory();
    final encryptedName = '$id.sajv';
    await File(p.join(dir.path, encryptedName)).writeAsBytes(encrypted, flush: true);
    try {
      final docs = await listDocuments();
      docs.add(VaultDocument(
        id: id,
        name: name,
        member: member,
        category: category,
        encryptedFile: encryptedName,
        addedAt: DateTime.now(),
        sizeBytes: bytes.length,
      ));
      await _saveIndex(docs);
    } catch (_) {
      final file = File(p.join(dir.path, encryptedName));
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<File> createTemporaryDecryptedCopy(VaultDocument doc) async {
    _requireUnlocked();
    final dir = await _directory();
    final encryptedFile = File(p.join(dir.path, doc.encryptedFile));
    final clear = await _decrypt(await encryptedFile.readAsBytes());
    final temp = await getTemporaryDirectory();
    final safeName = doc.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final output = File(p.join(temp.path, '${doc.id}_$safeName'));
    await output.writeAsBytes(clear, flush: true);
    return output;
  }

  Future<void> deleteDocument(VaultDocument doc) async {
    _requireUnlocked();
    final dir = await _directory();
    final file = File(p.join(dir.path, doc.encryptedFile));
    if (await file.exists()) await file.delete();
    final docs = await listDocuments();
    docs.removeWhere((item) => item.id == doc.id);
    await _saveIndex(docs);
  }
}
