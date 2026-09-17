import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// 密文信封：把一段字节加密成可直接落盘的 JSON 文本，并可原样解回。
///
/// 文字存储与图片存储共用同一把主密钥与同一套信封格式。抽出来不只是为了
/// 少写代码——**「磁盘上的数据长什么样」应该只有一个答案**，
/// 否则安全审计要看两处，而两处还会悄悄漂移。
class SecretEnvelope {
  SecretEnvelope({required List<int> masterKey})
      : _algorithm = AesGcm.with256bits(),
        _masterKey = SecretKey(masterKey);

  /// 信封格式版本。将来更换算法时靠它识别并迁移旧文件。
  static const int formatVersion = 1;

  /// 信封里声明的算法名。只用于可读性与排障，解密不依赖它。
  static const String algorithmName = 'AES-256-GCM';

  final AesGcm _algorithm;
  final SecretKey _masterKey;

  /// 加密。返回的 JSON 文本可直接写文件。
  Future<String> seal(List<int> clearBytes) async {
    final box = await _algorithm.encrypt(clearBytes, secretKey: _masterKey);
    return jsonEncode(<String, Object?>{
      'v': formatVersion,
      'alg': algorithmName,
      'nonce': base64Encode(box.nonce),
      'data': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  /// 解密。
  ///
  /// 信封不是 JSON、版本不符、或被篡改（GCM 认证标签校验失败）都会抛异常，
  /// 由调用方决定是隔离、跳过还是降级——本类不替调用方做数据处置决定。
  Future<List<int>> open(String envelopeText) async {
    final Object? envelope = jsonDecode(envelopeText);
    if (envelope is! Map) {
      throw const FormatException('密文信封不是 JSON 对象');
    }

    final fields = Map<String, Object?>.from(envelope);
    final Object? version = fields['v'];
    if (version != formatVersion) {
      throw FormatException('不支持的存储格式版本：$version');
    }

    return _algorithm.decrypt(
      SecretBox(
        _decodeBytes(fields, 'data'),
        nonce: _decodeBytes(fields, 'nonce'),
        mac: Mac(_decodeBytes(fields, 'mac')),
      ),
      secretKey: _masterKey,
    );
  }

  static List<int> _decodeBytes(Map<String, Object?> fields, String name) {
    final Object? value = fields[name];
    if (value is! String) {
      throw FormatException('密文信封缺少字段：$name');
    }
    return base64Decode(value);
  }
}
